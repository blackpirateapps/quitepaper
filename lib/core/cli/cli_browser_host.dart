import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../web_clipper/html_to_markdown_converter.dart';
import '../web_clipper/web_clipper_models.dart';
import '../utils/tag_parser.dart';
import 'cli_database.dart';

/// Browser native messaging transport. Stdout contains framed JSON only.
/// This path deliberately has no acquisition, HTTP, image probing or sync client.
class CliBrowserHost {
  CliBrowserHost(this.database);

  final CliDatabase Function() database;
  static const protocolVersion = 1;
  static const maxMessageBytes = 8 * 1024 * 1024;

  Future<int> serve(
    Stream<List<int>> input,
    StreamSink<List<int>> output,
  ) async {
    final reader = _NativeReader(input);
    try {
      while (true) {
        final header = await reader.read(4);
        if (header == null) return 0;
        final length = ByteData.sublistView(header).getUint32(0, Endian.host);
        if (length == 0 || length > maxMessageBytes) {
          throw const FormatException('Capture exceeds the 8 MiB limit.');
        }
        final bytes = await reader.read(length);
        if (bytes == null) throw const FormatException('Truncated message.');
        Map<String, Object?> response;
        try {
          response = handle(jsonDecode(utf8.decode(bytes)));
        } catch (e) {
          response = {'ok': false, 'error': e.toString()};
        }
        output.add(encode(response));
        // IOSink flushes on its own; do not close process stdout between messages.
      }
    } on FormatException catch (e) {
      output.add(encode({'ok': false, 'error': e.message}));
      return 65;
    } finally {
      await reader.cancel();
    }
  }

  static Uint8List encode(Map<String, Object?> message) {
    final bytes = utf8.encode(jsonEncode(message));
    final header = ByteData(4)..setUint32(0, bytes.length, Endian.host);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...bytes]);
  }

  Map<String, Object?> handle(Object? request) {
    if (request is! Map<String, dynamic> ||
        request['version'] != protocolVersion) {
      throw const FormatException('Unsupported browser clip protocol.');
    }
    if (request['action'] == 'ping') {
      return {'ok': true, 'version': protocolVersion};
    }
    if (request['action'] != 'clip') {
      throw const FormatException('Unsupported browser action.');
    }
    String field(String key, {int limit = 4096, bool required = false}) {
      final value = request[key];
      if (value == null && !required) return '';
      if (value is! String ||
          value.length > limit ||
          (required && value.trim().isEmpty)) {
        throw FormatException('Invalid $key.');
      }
      return value.trim();
    }

    final source = field('url', limit: 16384, required: true);
    final uri = Uri.tryParse(source);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Only HTTP and HTTPS pages can be clipped.');
    }
    final title = field('title', required: true);
    final content = field('html', limit: maxMessageBytes, required: true);
    final tags = request['tags'] ?? <String>[];
    if (tags is! List ||
        tags.length > 50 ||
        tags.any(
          (tag) =>
              tag is! String ||
              tag.length > 100 ||
              tag.contains(RegExp(r'[\r\n\x00-\x1f]')),
        )) {
      throw const FormatException('Invalid tags.');
    }
    final normalizedTags = tags
        .cast<String>()
        .map(TagParser.normalizeTag)
        .toSet();
    if (normalizedTags.any((tag) => !TagParser.isValidTag(tag))) {
      throw const FormatException(
        'Tags must use letters, numbers, hyphens or underscores; '
        'use / for nested tags and commas between tags.',
      );
    }
    final body = html.parse(content).body!;
    _sanitize(body, uri);
    if (body.text.trim().isEmpty && body.querySelector('img') == null) {
      throw const FormatException('This page has no readable content to save.');
    }
    final domainTag = uri.host
        .replaceFirst(RegExp(r'^www\.'), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    final metadata = ExtractedArticleMetadata(
      sourceUrl: uri.toString(),
      title: title,
      // Dots are not valid Quiet Paper tag characters. A web/ parent also
      // supports numeric hosts without creating an invalid numeric root tag.
      domain: 'web/$domainTag',
      author: field('author'),
      description: field('description'),
      publishedDate: DateTime.tryParse(field('publishedAt')),
    );
    final note = database().createNote(
      title: title,
      content: const HtmlToMarkdownConverter().convert(
        cleanedElement: body,
        metadata: metadata,
        tags: normalizedTags.toList(),
      ),
      tags: ['clipped', metadata.domain, ...normalizedTags],
    );
    return {
      'ok': true,
      'id': note.id,
      'title': note.title,
      'savedLocally': true,
    };
  }

  /// Defense in depth for captures supplied by a browser. Never resolve local
  /// files, execute active content, or allow page HTML to inject vault URIs.
  static void _sanitize(dom.Element body, Uri base) {
    for (final node in body.querySelectorAll(
      'script, style, noscript, iframe, object, embed, form, input, textarea, '
      'select, button, svg, canvas, template, link, meta, base',
    )) {
      node.remove();
    }
    for (final node in body.querySelectorAll('*')) {
      final attributes = Map.of(node.attributes);
      node.attributes.clear();
      for (final name in ['href', 'src']) {
        final raw = attributes[name];
        if (raw == null || raw.trim().isEmpty) continue;
        final resolved = base.resolve(raw.trim());
        if ((['http', 'https'].contains(resolved.scheme) &&
                resolved.host.isNotEmpty &&
                resolved.userInfo.isEmpty) ||
            (name == 'href' && resolved.scheme == 'mailto')) {
          node.attributes[name] = resolved.toString();
        }
      }
      for (final name in ['alt', 'title']) {
        if (attributes[name] != null) node.attributes[name] = attributes[name]!;
      }
      // Preserve fenced code language for the shared Markdown converter.
      if (node.localName == 'code' || node.localName == 'pre') {
        final language = RegExp(
          r'\blanguage-[a-zA-Z0-9_-]+',
        ).firstMatch(attributes['class'] ?? '')?.group(0);
        if (language != null) node.attributes['class'] = language;
      }
    }
  }
}

class _NativeReader {
  _NativeReader(Stream<List<int>> input) : _iterator = StreamIterator(input);
  final StreamIterator<List<int>> _iterator;
  List<int> _chunk = const [];
  int _offset = 0;

  Future<Uint8List?> read(int count) async {
    final bytes = Uint8List(count);
    var used = 0;
    while (used < count) {
      if (_offset == _chunk.length) {
        if (!await _iterator.moveNext()) {
          if (used == 0) return null;
          throw const FormatException('Truncated message.');
        }
        _chunk = _iterator.current;
        _offset = 0;
        if (_chunk.isEmpty) continue;
      }
      final available = _chunk.length - _offset;
      final take = available < count - used ? available : count - used;
      bytes.setRange(used, used + take, _chunk, _offset);
      _offset += take;
      used += take;
    }
    return bytes;
  }

  Future<void> cancel() => _iterator.cancel();
}
