import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/text/attachment_text_decoder.dart';

void main() {
  group('AttachmentTextDecoder Tests', () {
    test('decodes standard UTF-8 text without BOM accurately', () {
      final input = 'Hello world!\nLine 2\nLine 3';
      final bytes = Uint8List.fromList(utf8.encode(input));

      final result = AttachmentTextDecoder.decode(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.text, input);
      expect(result.encoding, TextEncoding.utf8);
      expect(result.hasBom, isFalse);
      expect(result.lineEnding, LineEnding.lf);
      expect(result.lineCount, 3);
      expect(result.isTruncated, isFalse);
      expect(result.totalByteSize, bytes.length);
    });

    test('detects and strips UTF-8 BOM from presentation string', () {
      final textContent = 'Quiet Paper with BOM\nSecond line';
      final rawBytes = Uint8List.fromList([
        0xEF, 0xBB, 0xBF, // UTF-8 BOM
        ...utf8.encode(textContent),
      ]);

      final result = AttachmentTextDecoder.decode(rawBytes);

      expect(result.isSuccess, isTrue);
      expect(result.text, textContent);
      expect(result.hasBom, isTrue);
      expect(result.encoding, TextEncoding.utf8Bom);
      expect(result.text.startsWith('\uFEFF'), isFalse);
      expect(result.lineCount, 2);
    });

    test('decodes UTF-16 LE with BOM accurately', () {
      final textContent = 'UTF-16 Little Endian';
      final codeUnits = textContent.codeUnits;
      final bytesList = <int>[0xFF, 0xFE]; // LE BOM
      for (final cu in codeUnits) {
        bytesList.add(cu & 0xFF);
        bytesList.add((cu >> 8) & 0xFF);
      }

      final result = AttachmentTextDecoder.decode(Uint8List.fromList(bytesList));

      expect(result.isSuccess, isTrue);
      expect(result.text, textContent);
      expect(result.encoding, TextEncoding.utf16Le);
      expect(result.hasBom, isTrue);
    });

    test('decodes UTF-16 BE with BOM accurately', () {
      final textContent = 'UTF-16 Big Endian';
      final codeUnits = textContent.codeUnits;
      final bytesList = <int>[0xFE, 0xFF]; // BE BOM
      for (final cu in codeUnits) {
        bytesList.add((cu >> 8) & 0xFF);
        bytesList.add(cu & 0xFF);
      }

      final result = AttachmentTextDecoder.decode(Uint8List.fromList(bytesList));

      expect(result.isSuccess, isTrue);
      expect(result.text, textContent);
      expect(result.encoding, TextEncoding.utf16Be);
      expect(result.hasBom, isTrue);
    });

    test('detects line endings accurately (LF, CRLF, CR, Mixed)', () {
      final lfBytes = Uint8List.fromList(utf8.encode('a\nb\nc'));
      expect(AttachmentTextDecoder.decode(lfBytes).lineEnding, LineEnding.lf);

      final crlfBytes = Uint8List.fromList(utf8.encode('a\r\nb\r\nc'));
      expect(AttachmentTextDecoder.decode(crlfBytes).lineEnding, LineEnding.crlf);

      final crBytes = Uint8List.fromList(utf8.encode('a\rb\rc'));
      expect(AttachmentTextDecoder.decode(crBytes).lineEnding, LineEnding.cr);

      final mixedBytes = Uint8List.fromList(utf8.encode('a\r\nb\nc'));
      expect(AttachmentTextDecoder.decode(mixedBytes).lineEnding, LineEnding.mixed);
    });

    test('computes accurate line counts across different newline structures', () {
      expect(AttachmentTextDecoder.decode(Uint8List(0)).lineCount, 0);

      final singleLine = Uint8List.fromList(utf8.encode('Single line without trailing newline'));
      expect(AttachmentTextDecoder.decode(singleLine).lineCount, 1);

      final singleLineTrailing = Uint8List.fromList(utf8.encode('Single line with trailing newline\n'));
      expect(AttachmentTextDecoder.decode(singleLineTrailing).lineCount, 2);

      final fiveLines = Uint8List.fromList(utf8.encode('1\n2\n3\n4\n5'));
      expect(AttachmentTextDecoder.decode(fiveLines).lineCount, 5);

      final crlfLines = Uint8List.fromList(utf8.encode('1\r\n2\r\n3\r\n4'));
      expect(AttachmentTextDecoder.decode(crlfLines).lineCount, 4);
    });

    test('preserves Unicode punctuation, accents, CJK, and emoji perfectly', () {
      final unicodeSample = 'Smart quotes ‘test’ and “quotes” — em-dash…\n'
          'Accents: café, naïve, résumé\n'
          'CJK: 日本語, 中文, 한국어\n'
          'Emoji: 📝 🌿 🔒 ✨\n'
          'Math: • © ® ° ± ≤ ≥ → ←';

      final bytes = Uint8List.fromList(utf8.encode(unicodeSample));
      final result = AttachmentTextDecoder.decode(bytes);

      expect(result.isSuccess, isTrue);
      expect(result.text, unicodeSample);
    });

    test('handles bounded reading and truncation for large payloads', () {
      // Create a 20 KB text payload and request maxBytes = 2048
      final buffer = StringBuffer();
      for (int i = 1; i <= 1000; i++) {
        buffer.writeln('Log entry line number $i in application test run');
      }
      final fullText = buffer.toString();
      final fullBytes = Uint8List.fromList(utf8.encode(fullText));

      final result = AttachmentTextDecoder.decode(fullBytes, maxBytes: 2048);

      expect(result.isSuccess, isTrue);
      expect(result.isTruncated, isTrue);
      expect(result.loadedByteSize, 2048);
      expect(result.totalByteSize, fullBytes.length);
      expect(result.text.length, lessThan(fullText.length));
    });

    test('handles empty 0-byte input cleanly', () {
      final result = AttachmentTextDecoder.decode(Uint8List(0));

      expect(result.isSuccess, isTrue);
      expect(result.text, '');
      expect(result.lineCount, 0);
      expect(result.lineEnding, LineEnding.none);
      expect(result.totalByteSize, 0);
    });

    test('handles Latin-1 fallback for legacy 8-bit text', () {
      // Latin-1 bytes with accented characters (0xE9 = é, 0xE0 = à)
      final latin1Bytes = Uint8List.fromList([
        0x52, 0xE9, 0x73, 0x75, 0x6D, 0xE9, // Résumé in Latin-1
      ]);

      final result = AttachmentTextDecoder.decode(latin1Bytes);

      expect(result.isSuccess, isTrue);
      expect(result.text, 'Résumé');
      expect(result.encoding, TextEncoding.latin1);
    });
  });
}
