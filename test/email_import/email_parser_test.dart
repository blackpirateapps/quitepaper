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
  test('pre-DOM HTML token budget rejects tiny-element allocation attacks', () {
    expect(
      () => EmailHtmlConverter().convert('<b></b>' * 60000),
      throwsA(
        isA<EmailImportException>().having(
          (e) => e.code,
          'code',
          'html_complexity',
        ),
      ),
    );
  });
  test(
    'plaintext headings and rules remain literal; quotes and lists remain readable',
    () {
      expect(
        EmailHtmlConverter.plainText('# Heading\n---\n> reply\n- item'),
        r'\# Heading'
        '\n'
        r'\---'
        '\n> reply\n- item',
      );
    },
  );
  test('nested layout tables preserve paragraphs, code and meaningful links', () {
    final text = EmailHtmlConverter().convert(
      '<table role="presentation"><tr><td><p>First</p><table><tr><td><p>Second</p><pre>code()</pre></td></tr></table><p>Third</p></td></tr></table>',
    );
    for (final word in ['First', 'Second', 'Third', 'code()']) {
      expect(RegExp(RegExp.escape(word)).allMatches(text), hasLength(1));
    }
    expect(text, contains('First\n\nSecond'));
    expect(text, contains('```'));
    expect(
      EmailHtmlConverter().convert('<a href="http:relative">inert</a>'),
      'inert',
    );
  });
  test('unsupported encoded headers reject without sensitive diagnostics', () {
    final value = utf8
        .decode(fixture('plain'))
        .replaceFirst(
          'Subject: Example',
          'Subject: =?x-unknown?B?cHJpdmF0ZQ==?=',
        );
    expect(
      () => parser.parseSync(Uint8List.fromList(utf8.encode(value))),
      throwsA(isA<EmailImportException>()),
    );
  });
  test(
    'pre-DOM nesting budget handles deep formatting without rejecting optional paragraph closures',
    () {
      expect(
        () => EmailHtmlConverter().convert('${'<b>' * 100}text${'</b>' * 100}'),
        throwsA(isA<EmailImportException>()),
      );
      expect(
        EmailHtmlConverter().convert('<p>Readable' * 100),
        contains('Readable'),
      );
    },
  );
  test('decoded charset expansion counts UTF-8 body bytes before conversion', () {
    final bytes = Uint8List.fromList([
      ...utf8.encode(
        'From: a@example.test\nSubject: Latin\nContent-Type: text/plain; charset=windows-1252\n\n',
      ),
      128,
      128,
    ]);
    expect(
      () =>
          const EmailParser(limits: EmailLimits(bodyBytes: 3)).parseSync(bytes),
      throwsA(isA<EmailImportException>()),
    );
  });
  test('quoted-printable soft lines and CRLF plaintext preserve content', () {
    for (final newline in ['\n', '\r\n']) {
      final source =
          'From: a@example.test\nSubject: Lines\nContent-Transfer-Encoding: quoted-printable\n\nFirst=\nSecond\n> Reply\n- item'
              .replaceAll('\n', newline);
      final parsed = parser.parseSync(Uint8List.fromList(utf8.encode(source)));
      expect(parsed.markdown, contains('FirstSecond'));
      expect(parsed.markdown, contains('> Reply'));
      expect(parsed.markdown, contains('- item'));
    }
  });
  test(
    'canonical fingerprints preserve meaningful case and paragraph structure',
    () {
      expect(
        EmailParser.fingerprint('Sender', 'Subject', 'date', 'PAID'),
        isNot(EmailParser.fingerprint('Sender', 'Subject', 'date', 'paid')),
      );
      expect(
        EmailParser.fingerprint('Sender', 'Subject', 'date', 'a\n\nb'),
        isNot(EmailParser.fingerprint('Sender', 'Subject', 'date', 'a b')),
      );
      final shared = parser.sharedText(text: 'Shared body');
      expect(
        shared.fingerprint,
        EmailParser.fingerprint(
          shared.sender,
          shared.subject,
          shared.originalDate,
          shared.markdown,
        ),
      );
    },
  );
  test(
    'invalid calendar, clock and timezone do not normalize into invented dates',
    () {
      for (final date in [
        '31 Feb 2026 10:00:00 +0000',
        '18 Nov 2026 25:80:00 +0000',
        '18 Nov 2026 10:00:00 +2460',
        '18 Nov 2026 10:00:00 UNKNOWN',
        '18 Nov 2026 10:00:00',
      ]) {
        expect(EmailParser.strictSentDate(date), isNull);
      }
      expect(
        EmailParser.strictSentDate('18 Nov 2026 10:30:00 +0530'),
        DateTime.utc(2026, 11, 18, 5),
      );
    },
  );
  test(
    'generic-file inspection only recognizes a continuous initial header block',
    () {
      expect(
        EmailParser.looksLikeEmail(
          utf8.encode(
            'Ordinary Markdown\n\nFrom: a@example.test\nSubject: quotation\n\nBody',
          ),
        ),
        isFalse,
      );
      expect(
        EmailParser.looksLikeEmail(
          utf8.encode(
            'not a header\nFrom: a@example.test\nSubject: quotation\n\nBody',
          ),
        ),
        isFalse,
      );
      expect(EmailParser.looksLikeEmail(fixture('folded')), isTrue);
    },
  );
  test(
    'unterminated HTML tags cannot cause repeated full-body regex scans',
    () {
      final malformed = '<a ' * 90000;
      expect(() => EmailHtmlConverter().convert(malformed), returnsNormally);
      expect(
        () => EmailHtmlConverter().convert('<a title="${'x' * 70000}">'),
        throwsA(isA<EmailImportException>()),
      );
    },
  );
}
