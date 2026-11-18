import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:enough_mail/codecs.dart';
import '../domain/email_message.dart';
import 'email_html_converter.dart';

/// enough_mail provides RFC header/parameter/date/charset codecs. A bounded
/// adapter walks MIME ranges before decoding; library convenience parsing is
/// intentionally avoided because it eagerly traverses parts and prints errors.
class EmailParser {
  const EmailParser({this.limits = const EmailLimits()});
  final EmailLimits limits;

  Future<EmailMessage> parse(Uint8List bytes) =>
      Isolate.run(() => parseSync(bytes));

  EmailMessage parseSync(Uint8List bytes) => runZoned(() {
    try {
      return _parse(bytes);
    } on EmailImportException {
      rethrow;
    } catch (_) {
      throw const EmailImportException(
        'invalid_email',
        'This file is not a valid supported email.',
      );
    }
  }, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));

  static bool looksLikeEmail(List<int> bytes) {
    final prefix = latin1.decode(bytes.take(65536).toList());
    final fields = RegExp(
      r'^(from|to|subject|date|message-id|mime-version|content-type):',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(prefix).map((m) => m[1]!.toLowerCase()).toSet();
    return fields.length >= 2 &&
        fields.any({'from', 'to', 'date', 'message-id'}.contains);
  }

  EmailMessage _parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > limits.rawBytes) {
      throw const EmailImportException(
        'raw_size',
        'Email is empty or exceeds the 50 MiB import limit.',
      );
    }
    if (!looksLikeEmail(bytes)) {
      throw const EmailImportException(
        'invalid_email',
        'The file does not contain a recognizable email message.',
      );
    }
    final raw = latin1.decode(bytes);
    var partCount = 0, attachmentTotal = 0, bodyTotal = 0;
    final attachments = <EmailAttachment>[];
    final warnings = <String>[];
    Map<String, List<String>>? topHeaders;

    String display(String value) {
      // Reconstitute RFC 6532 UTF-8 from the lossless transport-byte view.
      value = utf8.decode(latin1.encode(value), allowMalformed: true);
      return MailCodec.decodeHeader(value) ?? '';
    }

    _Body walk(int start, int end, int depth) {
      if (++partCount > limits.parts || depth > limits.depth) {
        throw const EmailImportException(
          'mime_complexity',
          'Email has too many MIME parts or nesting levels.',
        );
      }
      final headerEnd = RegExp(r'\r?\n\r?\n').firstMatch(
        raw.substring(
          start,
          (start + limits.headerBytes + 4).clamp(start, end),
        ),
      );
      if (headerEnd == null) {
        throw const EmailImportException(
          'headers',
          'Email headers are incomplete or too large.',
        );
      }
      final bodyStart = start + headerEnd.end;
      final headerText = raw
          .substring(start, start + headerEnd.start)
          .replaceAll(RegExp(r'\r?\n[ \t]+'), ' ');
      final headers = <String, List<String>>{};
      for (final line in headerText.split(RegExp(r'\r?\n'))) {
        final colon = line.indexOf(':');
        if (colon <= 0) {
          throw const EmailImportException(
            'headers',
            'Email contains malformed headers.',
          );
        }
        final name = line.substring(0, colon).toLowerCase();
        (headers[name] ??= []).add(line.substring(colon + 1).trim());
      }
      topHeaders ??= headers;
      String h(String name) => headers[name]?.first ?? '';
      final type = ContentTypeHeader(
        h('content-type').isEmpty ? 'text/plain' : h('content-type'),
      );
      final mime = type.value.toLowerCase();
      final disposition = h('content-disposition').isEmpty
          ? null
          : ContentDispositionHeader(h('content-disposition'));
      if (mime.startsWith('multipart/')) {
        final boundary = type.boundary;
        if (boundary == null || boundary.isEmpty || boundary.length > 200) {
          throw const EmailImportException(
            'boundary',
            'Email has an invalid MIME boundary.',
          );
        }
        final pattern = RegExp(
          '^--${RegExp.escape(boundary)}(--)?[ \\t]*(?:\\r?\\n|\$)',
          multiLine: true,
        );
        int? childStart;
        var closed = false;
        final bodies = <_Body>[];
        for (final match in pattern.allMatches(raw, bodyStart)) {
          if (match.start >= end) break;
          if (childStart != null) {
            var childEnd = match.start;
            if (childEnd > childStart && raw[childEnd - 1] == '\n') childEnd--;
            if (childEnd > childStart && raw[childEnd - 1] == '\r') childEnd--;
            bodies.add(walk(childStart, childEnd, depth + 1));
          }
          if (match[1] != null) {
            closed = true;
            break;
          }
          childStart = match.end;
        }
        if (!closed || bodies.isEmpty) {
          throw const EmailImportException(
            'boundary',
            'Email has an incomplete MIME boundary.',
          );
        }
        return _Body(
          children: bodies,
          alternative: mime == 'multipart/alternative',
        );
      }
      final fileName = disposition?.filename ?? type.parameters['name'];
      final isBody =
          (mime == 'text/plain' || mime == 'text/html') &&
          fileName == null &&
          disposition?.value.toLowerCase() != 'attachment';
      final cap = isBody
          ? limits.bodyBytes - bodyTotal
          : (limits.attachmentBytes <
                    limits.totalAttachmentBytes - attachmentTotal
                ? limits.attachmentBytes
                : limits.totalAttachmentBytes - attachmentTotal);
      final encoded = raw.substring(bodyStart, end);
      final encoding = h('content-transfer-encoding').toLowerCase();
      final decoded = _decode(encoded, encoding, cap);
      if (isBody) {
        bodyTotal += decoded.length;
        final charset = type.charset;

        // Unknown codecs in upstream report through print. Fail rather than
        // silently importing undecoded data; supported aliases are preflighted.
        if (charset != null && !_supportedCharset(charset)) {
          throw const EmailImportException(
            'charset',
            'This email uses an unsupported character encoding.',
          );
        }
        final text = MailCodec.decodeAsText(decoded, '8bit', charset);
        if (mime == 'text/html') {
          // Conversion is delayed until CID parts have been collected.
          return _Body(text: text, html: true);
        }
        return _Body(text: EmailHtmlConverter.plainText(text));
      }
      attachmentTotal += decoded.length;
      if (attachmentTotal > limits.totalAttachmentBytes) {
        throw const EmailImportException(
          'attachment_total',
          'Decoded email attachments exceed 50 MiB.',
        );
      }
      final cid = EmailHtmlConverter.normalizeCid(h('content-id'));
      attachments.add(
        EmailAttachment(
          fileName: sanitizeFileName(
            fileName ??
                (mime == 'message/rfc822'
                    ? 'attached-email.eml'
                    : 'attachment-${attachments.length + 1}'),
          ),
          mimeType: mime,
          bytes: decoded,
          contentId: cid.isEmpty ? null : cid,
          disposition: disposition?.value,
        ),
      );
      return const _Body();
    }

    final tree = walk(0, raw.length, 0);
    final cidSet = attachments
        .where((a) => a.isInlineImage)
        .map((a) => a.contentId!)
        .toSet();
    String render(_Body node) {
      if (node.children.isNotEmpty) {
        if (node.alternative) {
          for (final child in node.children.reversed.where(
            (b) => b.html || b.children.isNotEmpty,
          )) {
            final content = render(child);
            if (content.trim().isNotEmpty) return content;
          }
          return node.children
              .map(render)
              .firstWhere((b) => b.trim().isNotEmpty, orElse: () => '');
        }
        return node.children
            .map(render)
            .where((b) => b.trim().isNotEmpty)
            .join('\n\n');
      }
      return node.html
          ? EmailHtmlConverter().convert(node.text, contentIds: cidSet)
          : node.text;
    }

    final body = render(tree);
    final headers = topHeaders!;
    String h(String name) => headers[name]?.map(display).join(', ') ?? '';
    final subject = h('subject').trim();
    final sender = h('from').trim();
    final date = h('date');
    DateTime? sentAt;
    try {
      sentAt = DateCodec.decodeDate(date)?.toUtc();
    } catch (_) {
      /* Date unavailable. */
    }
    if (headers.values.any((v) => v.length > 1)) {
      warnings.add('Duplicate headers are preserved in the original email.');
    }
    return EmailMessage(
      subject: subject.isEmpty ? 'Untitled Email' : subject,
      sender: sender.isEmpty ? 'Unknown sender' : sender,
      to: h('to'),
      cc: h('cc'),
      bcc: h('bcc'),
      replyTo: h('reply-to'),
      originalDate: date,
      sentAt: sentAt,
      messageId: normalizeMessageId(h('message-id')),
      inReplyTo: normalizeMessageId(h('in-reply-to')),
      references: RegExp(r'<[^<>]+>')
          .allMatches(h('references'))
          .map((m) => normalizeMessageId(m[0]!)!)
          .toList(),
      markdown: body.trim(),
      attachments: attachments,
      rawBytes: bytes,
      rawHash: sha256.convert(bytes).toString(),
      fingerprint: fingerprint(sender, subject, date, body),
      warnings: warnings,
    );
  }

  EmailMessage sharedText({
    required String text,
    String subject = '',
    String sender = '',
    String to = '',
    String date = '',
    bool isHtml = false,
  }) {
    if (utf8.encode(text).length > limits.bodyBytes) {
      throw const EmailImportException(
        'body_size',
        'Shared content exceeds 10 MiB.',
      );
    }
    final markdown = isHtml
        ? EmailHtmlConverter().convert(text)
        : EmailHtmlConverter.plainText(text);
    return EmailMessage(
      subject: subject.trim().isEmpty ? 'Untitled Email' : subject.trim(),
      sender: sender.trim().isEmpty ? 'Unknown sender' : sender.trim(),
      to: to,
      originalDate: date,
      sentAt: DateTime.tryParse(date),
      markdown: markdown,
      fingerprint: fingerprint(sender, subject, date, markdown),
    );
  }

  static String? normalizeMessageId(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'^<|>$'), '')
        .toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  static String fingerprint(
    String sender,
    String subject,
    String date,
    String body,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            [sender, subject, date, body]
                .map(
                  (v) => v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
                )
                .toList(),
          ),
        ),
      )
      .toString();
  static String sanitizeFileName(String name) {
    final safe = name
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*\[\]()]'), '_')
        .trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return 'attachment';
    return safe.length > 180 ? safe.substring(safe.length - 180) : safe;
  }

  static bool _supportedCharset(String value) => RegExp(
    r'^(utf-?8|us-ascii|ascii|latin-?1|iso-?8859-?(?:[1-9]|1[0-6])|windows-125[0-46]|cp-?125[0-46]|gbk|gb-?2312|gb18030|big-?5|koi8(?:-[ru])?)$',
    caseSensitive: false,
  ).hasMatch(value);
  Uint8List _decode(String value, String encoding, int cap) {
    if (!{
      '',
      '7bit',
      '8bit',
      'binary',
      'base64',
      'quoted-printable',
    }.contains(encoding)) {
      throw const EmailImportException(
        'transfer_encoding',
        'Email uses an unsupported transfer encoding.',
      );
    }
    var size = 0;
    if (encoding == 'base64') {
      var count = 0;
      for (final unit in value.codeUnits) {
        if (unit == 32 || unit == 9 || unit == 13 || unit == 10) continue;
        count++;
      }
      size = (count ~/ 4) * 3;
      // Allow up to two padding bytes in the preflight estimate.
      if (size > cap + 2) {
        throw const EmailImportException(
          'decoded_size',
          'Email body or attachment exceeds the import size limit.',
        );
      }
      final clean = value.replaceAll(RegExp(r'\s'), '');
      if (clean.length % 4 != 0 ||
          !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(clean)) {
        throw const EmailImportException(
          'base64',
          'Email contains corrupted base64 data.',
        );
      }
      final bytes = base64Decode(clean);
      if (bytes.length > cap) {
        throw const EmailImportException(
          'decoded_size',
          'Email body or attachment exceeds the import size limit.',
        );
      }
      return bytes;
    }
    if (encoding == 'quoted-printable') {
      for (var i = 0; i < value.length; i++) {
        if (value[i] == '=') {
          if (value.startsWith('=\r\n', i)) {
            i += 2;
            continue;
          }
          if (value.startsWith('=\n', i)) {
            i++;
            continue;
          }
          if (i + 2 >= value.length ||
              !RegExp(
                r'^[0-9a-fA-F]{2}$',
              ).hasMatch(value.substring(i + 1, i + 3))) {
            throw const EmailImportException(
              'quoted_printable',
              'Email contains corrupted quoted-printable data.',
            );
          }
          i += 2;
        }
        if (++size > cap) {
          throw const EmailImportException(
            'decoded_size',
            'Email body or attachment exceeds the import size limit.',
          );
        }
      }
      return MailCodec.quotedPrintable.decodeData(value);
    }
    if (value.length > cap) {
      throw const EmailImportException(
        'decoded_size',
        'Email body or attachment exceeds the import size limit.',
      );
    }
    return Uint8List.fromList(value.codeUnits);
  }
}

class _Body {
  const _Body({
    this.text = '',
    this.html = false,
    this.children = const [],
    this.alternative = false,
  });
  final String text;
  final bool html, alternative;
  final List<_Body> children;
}
