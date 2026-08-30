import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/text/attachment_text_detector.dart';

void main() {
  group('AttachmentTextDetector Tests', () {
    test('classifies standard text extensions correctly', () {
      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'notes.txt',
          bytes: Uint8List.fromList(utf8.encode('Hello world')),
        ),
        TextAttachmentFormat.plainText,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'README.md',
          bytes: Uint8List.fromList(utf8.encode('# Title\n\nBody')),
        ),
        TextAttachmentFormat.markdown,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'doc.mdown',
          bytes: Uint8List.fromList(utf8.encode('# Markdown')),
        ),
        TextAttachmentFormat.markdown,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'data.csv',
          bytes: Uint8List.fromList(utf8.encode('a,b,c\n1,2,3')),
        ),
        TextAttachmentFormat.csv,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'table.tsv',
          bytes: Uint8List.fromList(utf8.encode('a\tb\tc\n1\t2\t3')),
        ),
        TextAttachmentFormat.tsv,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'config.json',
          bytes: Uint8List.fromList(utf8.encode('{"key": "value"}')),
        ),
        TextAttachmentFormat.json,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'events.jsonl',
          bytes: Uint8List.fromList(utf8.encode('{"id": 1}\n{"id": 2}')),
        ),
        TextAttachmentFormat.json,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'config.yaml',
          bytes: Uint8List.fromList(utf8.encode('key: value')),
        ),
        TextAttachmentFormat.yaml,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'app.xml',
          bytes: Uint8List.fromList(utf8.encode('<root><item/></root>')),
        ),
        TextAttachmentFormat.xml,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'Cargo.toml',
          bytes: Uint8List.fromList(utf8.encode('[package]\nname = "test"')),
        ),
        TextAttachmentFormat.toml,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'server.log',
          bytes: Uint8List.fromList(utf8.encode('[INFO] Server started')),
        ),
        TextAttachmentFormat.log,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: '.env',
          bytes: Uint8List.fromList(utf8.encode('PORT=8080')),
        ),
        TextAttachmentFormat.config,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'settings.ini',
          bytes: Uint8List.fromList(utf8.encode('[Section]\nkey=1')),
        ),
        TextAttachmentFormat.config,
      );
    });

    test('classifies source code extensions correctly', () {
      final codeFiles = [
        'main.dart',
        'script.py',
        'app.js',
        'server.ts',
        'App.jsx',
        'Component.tsx',
        'Main.java',
        'App.kt',
        'View.swift',
        'lib.rs',
        'main.go',
        'program.c',
        'header.h',
        'engine.cpp',
        'Service.cs',
        'index.php',
        'script.rb',
        'deploy.sh',
        'query.sql',
        'page.html',
        'styles.css',
      ];

      for (final file in codeFiles) {
        expect(
          AttachmentTextDetector.detectFormat(
            fileName: file,
            bytes: Uint8List.fromList(utf8.encode('// code sample')),
          ),
          TextAttachmentFormat.sourceCode,
          reason: 'Expected $file to be classified as sourceCode',
        );
      }
    });

    test('handles unknown extensions with text vs binary content safely', () {
      // Valid text content in unknown extension
      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'custom.special_cfg',
          bytes: Uint8List.fromList(utf8.encode('param = 42\noption = enabled')),
        ),
        TextAttachmentFormat.unknownText,
      );

      // Binary content with null bytes in unknown extension
      final binaryBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00, 0x0D]);
      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'archive.custom',
          bytes: binaryBytes,
        ),
        TextAttachmentFormat.binary,
      );

      // Misleading text extension with null byte binary payload
      final fakeTxt = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x57, 0x6F, 0x72, 0x6C, 0x64]);
      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'corrupt.txt',
          bytes: fakeTxt,
        ),
        TextAttachmentFormat.binary,
      );
    });

    test('handles empty 0-byte files safely', () {
      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'empty.txt',
          bytes: Uint8List(0),
        ),
        TextAttachmentFormat.plainText,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'empty.md',
          bytes: Uint8List(0),
        ),
        TextAttachmentFormat.markdown,
      );

      expect(
        AttachmentTextDetector.detectFormat(
          fileName: 'empty_no_ext',
          bytes: Uint8List(0),
        ),
        TextAttachmentFormat.unknownText,
      );
    });

    test('verifies typography and layout policy flags', () {
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.sourceCode), isTrue);
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.log), isTrue);
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.json), isTrue);
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.csv), isTrue);
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.plainText), isFalse);
      expect(AttachmentTextDetector.isMonospaced(TextAttachmentFormat.markdown), isFalse);

      expect(AttachmentTextDetector.supportsLineNumbers(TextAttachmentFormat.sourceCode), isTrue);
      expect(AttachmentTextDetector.supportsLineNumbers(TextAttachmentFormat.log), isTrue);
      expect(AttachmentTextDetector.supportsLineNumbers(TextAttachmentFormat.json), isTrue);
      expect(AttachmentTextDetector.supportsLineNumbers(TextAttachmentFormat.plainText), isFalse);

      expect(AttachmentTextDetector.defaultWordWrap(TextAttachmentFormat.plainText), isTrue);
      expect(AttachmentTextDetector.defaultWordWrap(TextAttachmentFormat.markdown), isTrue);
      expect(AttachmentTextDetector.defaultWordWrap(TextAttachmentFormat.sourceCode), isFalse);
      expect(AttachmentTextDetector.defaultWordWrap(TextAttachmentFormat.log), isFalse);
    });

    test('provides human-readable category labels', () {
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.plainText),
        'Plain Text',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.markdown),
        'Markdown',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.csv),
        'CSV Spreadsheet',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.tsv),
        'TSV Spreadsheet',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.json),
        'JSON Document',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.sourceCode, fileName: 'main.dart'),
        'Dart Source',
      );
      expect(
        AttachmentTextDetector.getCategoryLabel(TextAttachmentFormat.sourceCode, fileName: 'script.py'),
        'Python Source',
      );
    });
  });
}
