import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/email_import/application/email_parser.dart';
import 'package:quitepaper/features/email_import/application/email_html_converter.dart';
import 'package:quitepaper/features/email_import/application/email_input.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/email_import/domain/note_import_source.dart';

Uint8List fixture(String name) =>
    File('test/email_import/fixtures/$name.eml').readAsBytesSync();
void main() {
  const parser = EmailParser();
  test('plain metadata, identifiers, source bytes and timestamps', () {
    final raw = fixture('plain');
    final email = parser.parseSync(raw);
    expect(email.subject, 'Example');
    expect(email.sender, contains('Alice'));
    expect(email.to, contains('Bob'));
    expect(email.markdown, 'Hello world.');
    expect(email.messageId, 'example@example.test');
    expect(email.sentAt, DateTime.utc(2026, 11, 18, 5));
    expect(email.originalDate, contains('+0530'));
    expect(email.rawBytes, orderedEquals(raw));
    expect(email.rawHash, hasLength(64));
  });
  test(
    'HTML only and multipart alternatives select one useful representation',
    () {
      expect(parser.parseSync(fixture('html')).markdown, contains('# Heading'));
      final alternative = parser.parseSync(fixture('alternative')).markdown;
      expect(alternative, 'HTML choice');
      expect(alternative, isNot(contains('Plain fallback')));
      final text = utf8
          .decode(fixture('alternative'))
          .replaceAll('<p>HTML choice</p>', '<script>hidden()</script>');
      expect(
        parser.parseSync(Uint8List.fromList(utf8.encode(text))).markdown,
        'Plain fallback',
      );
    },
  );
  test('mixed attachment bytes and related CID images remain local', () {
    final mixed = parser.parseSync(fixture('mixed'));
    expect(mixed.markdown, 'Body');
    expect(mixed.attachments.single.fileName, 'invoice.pdf');
    expect(mixed.attachments.single.bytes, utf8.encode('%PDF'));
    final related = parser.parseSync(fixture('related'));
    expect(related.markdown, contains('![Portrait](email-cid:photo)'));
    expect(related.attachments.single.contentId, 'photo');
    expect(parser.parseSync(fixture('nested')).markdown, contains('> Reply'));
  });
  test('encoded and UTF-8 headers, folded values and Unicode body', () {
    final encoded = parser.parseSync(fixture('encoded'));
    expect(encoded.subject, '✓ Order');
    expect(encoded.sender, contains('日本語'));
    final unicode = parser.parseSync(fixture('unicode'));
    expect(unicode.subject, '日本語');
    expect(unicode.markdown, 'नमस्ते 日本語 ✓');
    expect(parser.parseSync(fixture('folded')).subject, 'Folded Subject');
    expect(parser.parseSync(fixture('qp')).markdown, 'Café ✓');
    expect(parser.parseSync(fixture('base64')).markdown, 'Hello ✓');
  });
  test('RFC2231 continued filenames and attached messages', () {
    expect(
      parser.parseSync(fixture('filename')).attachments.single.fileName,
      '€invoice.pdf',
    );
    final nested = parser.parseSync(fixture('attached_email'));
    expect(nested.markdown, 'Body');
    expect(nested.attachments.single.mimeType, 'message/rfc822');
    expect(
      utf8.decode(nested.attachments.single.bytes),
      contains('Nested body'),
    );
  });
  test('missing metadata, invalid date, empty body and duplicate headers', () {
    expect(
      parser.parseSync(fixture('missing_subject')).subject,
      'Untitled Email',
    );
    expect(parser.parseSync(fixture('missing_from')).sender, 'Unknown sender');
    expect(parser.parseSync(fixture('invalid_date')).sentAt, isNull);
    expect(parser.parseSync(fixture('empty')).markdown, isEmpty);
    final duplicate = parser.parseSync(fixture('duplicate_headers'));
    expect(duplicate.subject, 'Example, Second subject');
    expect(duplicate.warnings, isNotEmpty);
  });
  test('LF and CRLF produce equal text and canonical fingerprints', () {
    final lf = fixture('plain');
    final crlf = Uint8List.fromList(
      utf8.encode(utf8.decode(lf).replaceAll('\n', '\r\n')),
    );
    expect(
      parser.parseSync(lf).fingerprint,
      parser.parseSync(crlf).fingerprint,
    );
    expect(parser.parseSync(lf).rawHash, isNot(parser.parseSync(crlf).rawHash));
  });
  for (final name in ['bad_boundary', 'bad_base64', 'unsupported_charset']) {
    test('rejects $name with sanitized error', () {
      expect(
        () => parser.parseSync(fixture(name)),
        throwsA(isA<EmailImportException>()),
      );
    });
  }
  test(
    'untrusted HTML cannot introduce remote images, active content or unsafe links',
    () {
      final body = parser.parseSync(fixture('malicious')).markdown;
      expect(body, contains('Visible'));
      expect(body, contains('[safe](https://safe.test/path)'));
      for (final forbidden in [
        'javascript:',
        'track.test',
        'iframe',
        '<script',
        'file:',
        'data:',
        'onclick',
      ]) {
        expect(body, isNot(contains(forbidden)));
      }
    },
  );
  test('traversal filenames and malicious CID references are inert', () {
    expect(
      EmailParser.sanitizeFileName('../../private/secret.txt'),
      'secret.txt',
    );
    expect(EmailParser.sanitizeFileName(r'..\..\evil.txt'), 'evil.txt');
    expect(
      EmailHtmlConverter().convert('<img src="cid:../../secret" alt="x">'),
      'x',
    );
    expect(
      EmailHtmlConverter().convert(
        '<p hidden>hidden</p><p style="display: none">also hidden</p><p>show</p>',
      ),
      'show',
    );
  });
  test(
    'structural conversion preserves headings, lists, quotes, tables and pre',
    () {
      final result = EmailHtmlConverter().convert(
        '<h2>Title</h2><ul><li>One</li><li>Two</li></ul><blockquote>Reply</blockquote><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table><pre>a &lt; b</pre>',
      );
      for (final text in [
        '## Title',
        '- One',
        '- Two',
        '> Reply',
        '| A | B |',
        '| 1 | 2 |',
        'a < b',
      ]) {
        expect(result, contains(text));
      }
    },
  );
  test(
    'limits apply before decoding large body, header, attachment and totals',
    () {
      expect(
        () => const EmailParser(
          limits: EmailLimits(bodyBytes: 2),
        ).parseSync(fixture('base64')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(attachmentBytes: 2),
        ).parseSync(fixture('mixed')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(totalAttachmentBytes: 2),
        ).parseSync(fixture('mixed')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(headerBytes: 8),
        ).parseSync(fixture('plain')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(rawBytes: 2),
        ).parseSync(fixture('plain')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(parts: 2),
        ).parseSync(fixture('mixed')),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailParser(
          limits: EmailLimits(depth: 1),
        ).parseSync(fixture('nested')),
        throwsA(isA<EmailImportException>()),
      );
    },
  );
  test('extremely nested multipart is rejected before stack exhaustion', () {
    var body = 'Content-Type: text/plain\n\ntext';
    for (var i = 0; i < 25; i++) {
      body =
          'Content-Type: multipart/mixed; boundary=b$i\n\n--b$i\n$body\n--b$i--\n';
    }
    expect(
      () => parser.parseSync(
        Uint8List.fromList(
          utf8.encode('From: x@example.test\nSubject: x\n$body'),
        ),
      ),
      throwsA(isA<EmailImportException>()),
    );
  });
  test('background parser and explicit shared content', () async {
    expect((await parser.parse(fixture('plain'))).subject, 'Example');
    final shared = parser.sharedText(
      text: '<script>literal</script> **plain**',
    );
    expect(shared.isSharedContent, isTrue);
    expect(shared.rawHash, isNull);
    expect(shared.markdown, contains(r'\<script\>'));
  });
  test(
    'input classification inspects content and does not trust extension',
    () async {
      expect(
        await const EmailInput(
          path: 'test/email_import/fixtures/plain.eml',
        ).isEmailCandidate(),
        isTrue,
      );
      expect(
        EmailParser.looksLikeEmail(utf8.encode('a normal shared paragraph')),
        isFalse,
      );
      expect(
        () => parser.parseSync(Uint8List.fromList(utf8.encode('a paragraph'))),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        () => const EmailInput(path: 'content://expired').localPath,
        throwsA(isA<EmailImportException>()),
      );
      expect(
        const EmailInput(path: 'file:///tmp/email%20file.eml').localPath,
        '/tmp/email file.eml',
      );
    },
  );
  test('provenance JSON is versioned, deterministic and union merged', () {
    final source = NoteImportSource(
      fingerprint: 'fingerprint',
      importedAt: DateTime.utc(2026),
      subject: 'Subject',
      sender: 'Sender',
      rawHash: 'hash',
    );
    expect(NoteImportSource.decode(jsonEncode([source.toJson()])), [source]);
    expect(NoteImportSource.union([source, source]), [source]);
    expect(NoteImportSource.decode(null), isEmpty);
  });
}
