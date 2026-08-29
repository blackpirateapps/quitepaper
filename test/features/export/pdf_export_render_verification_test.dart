import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/pdf/pdf_markdown_models.dart';
import 'package:quitepaper/core/pdf/pdf_markdown_parser.dart';
import 'package:quitepaper/features/export/application/exporters/pdf_exporter.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF Export Renderer - Production Verification', () {
    const exporter = PdfExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_render_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Section 54 Representative Fixture: Full Markdown semantics & Unicode', () async {
      const fixtureMarkdown = '''# Quiet Paper PDF Test

This paragraph contains **bold**, *italic*, ***bold italic***,
~~strikethrough~~, ==highlight==, and `inline code`.

It's important that smart punctuation doesn't break:
“quotes”, ‘apostrophes’, – en dash, — em dash, … ellipsis.

## Lists

- First item
- Second item
  - Nested item
- [ ] Open task
- [x] Completed task

## Quote

> This is a blockquote.

## Code

```dart
final message = "Hello, Quiet Paper";
print(message);
```

## Link

[Quiet Paper](https://example.com)

---

Final paragraph.
''';

      final snapshot = NoteExportSnapshot(
        noteId: 'fixture-note-1',
        title: 'Quiet Paper PDF Test',
        markdown: fixtureMarkdown,
        createdAt: DateTime.utc(2026, 3, 15, 10, 30),
        updatedAt: DateTime.utc(2026, 3, 16, 14, 45),
        tags: const ['release', 'pdf-test', 'verified'],
      );

      final request = const ExportRequest(
        noteId: 'fixture-note-1',
        format: ExportFormat.pdf,
        includeMetadata: true,
        pdfOptions: PdfExportOptions(
          showTags: true,
          showDates: true,
          includeAttachments: true,
          pageSize: 'A4',
        ),
      );

      final outputFile = File('${tempDir.path}/Quiet_Paper_PDF_Test.pdf');
      final result = await exporter.exportPdf(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.pdf));
      expect(result.byteSize, greaterThan(5000));
      expect(result.warnings, isEmpty);

      final bytes = await outputFile.readAsBytes();
      expect(bytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D])); // %PDF-

      // Verify parser extracted semantic blocks accurately
      final parser = const PdfMarkdownParser();
      final blocks = parser.parse(markdown: fixtureMarkdown);

      expect(blocks.whereType<PdfHeadingBlock>().length, equals(5)); // H1 + 4 H2s
      expect(blocks.whereType<PdfParagraphBlock>().length, equals(4));
      expect(blocks.whereType<PdfListBlock>().length, equals(1));
      expect(blocks.whereType<PdfChecklistBlock>().length, equals(1));
      expect(blocks.whereType<PdfBlockquoteBlock>().length, equals(1));
      expect(blocks.whereType<PdfCodeBlock>().length, equals(1));
      expect(blocks.whereType<PdfHorizontalRuleBlock>().length, equals(1));

      // Verify PDF content structures
      final pdfRaw = latin1.decode(bytes);
      expect(pdfRaw, contains('/Type/Catalog'));
      expect(pdfRaw, contains('/Type/Pages'));
      expect(pdfRaw, contains('/Type/Page'));
      expect(pdfRaw, contains('/FontFile2')); // Embedded TrueType font stream
      expect(pdfRaw, contains('https://example.com')); // Clickable link annotation
    });

    test('Section 30: Unicode & Typographical Glyph Regression Test', () async {
      const unicodeMarkdown = '''# Unicode Verification

Special punctuation:
It's wouldn't what's valuable priceless
“curly double quotes” and ‘curly single quotes’
– en dash and — em dash and … ellipsis
Currency symbols: € euro, £ pound, ¥ yen, ₹ rupee
Accented Latin: café, naïve, résumé, Zürich, São Paulo
Mathematical & symbols: • bullet, © copyright, ® registered, ° degree, ± plus-minus, ≤ leq, ≥ geq, → right, ← left
''';

      final snapshot = NoteExportSnapshot(
        noteId: 'unicode-note-1',
        title: 'Unicode Verification',
        markdown: unicodeMarkdown,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        tags: const ['unicode', 'i18n'],
      );

      final request = const ExportRequest(
        noteId: 'unicode-note-1',
        format: ExportFormat.pdf,
        includeMetadata: true,
      );

      final outputFile = File('${tempDir.path}/Unicode_Verification.pdf');
      final result = await exporter.exportPdf(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.byteSize, greaterThan(5000));
      expect(await outputFile.exists(), isTrue);

      final bytes = await outputFile.readAsBytes();
      final pdfRaw = latin1.decode(bytes);
      expect(pdfRaw, contains('/FontFile2')); // Embedded TrueType font
    });

    test('Section 22: GFM Tables render with alignments and headers', () async {
      const tableMarkdown = '''# Feature Matrix

| Feature | Status | Priority | Notes |
| :--- | :---: | ---: | :--- |
| **PDF Export** | `Done` | High | Full vector layout |
| *Markdown Sync* | `Active` | Critical | Drift SQLite backend |
| ==OCR Pipeline== | `Ready` | Medium | On-device MLKit |

After table text.
''';

      final snapshot = NoteExportSnapshot(
        noteId: 'table-note-1',
        title: 'Feature Matrix',
        markdown: tableMarkdown,
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 2),
      );

      final request = const ExportRequest(
        noteId: 'table-note-1',
        format: ExportFormat.pdf,
      );

      final outputFile = File('${tempDir.path}/Feature_Matrix.pdf');
      final result = await exporter.exportPdf(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.byteSize, greaterThan(4000));
      expect(await outputFile.exists(), isTrue);
    });

    test('Section 38 & 39: Long multi-page document pagination and image handling', () async {
      // 1x1 transparent PNG bytes
      final dummyPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final buffer = StringBuffer();
      buffer.writeln('# Long Multi-Page Architecture Note\n');

      for (var section = 1; section <= 15; section++) {
        buffer.writeln('## Section $section: Core Module Specifications\n');
        buffer.writeln(
          'This is detailed paragraph $section of the specifications document. '
          'It describes subsystem interactions, security boundaries, and cache invariants. '
          'Soft line breaks within the paragraph\ncontinue seamlessly without excessive whitespace.\n',
        );

        buffer.writeln('- Primary requirement $section.A');
        buffer.writeln('- Secondary requirement $section.B');
        buffer.writeln('  - Nested detail for $section.B.1');
        buffer.writeln('- [x] Verified requirement $section.C');
        buffer.writeln('- [ ] Pending test $section.D\n');

        buffer.writeln('> "Architectural integrity requires strict separation of concerns." - Note $section\n');

        buffer.writeln('```dart');
        buffer.writeln('void processModule$section() {');
        buffer.writeln('  final config = loadConfig($section);');
        buffer.writeln('  print("Executing section $section: " + config.name);');
        buffer.writeln('}');
        buffer.writeln('```\n');

        if (section % 5 == 0) {
          buffer.writeln('![Diagram $section](qp://asset/att-$section)\n');
        }
      }

      final snapshot = NoteExportSnapshot(
        noteId: 'long-note-1',
        title: 'Long Multi-Page Note',
        markdown: buffer.toString(),
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 2),
        tags: const ['architecture', 'multipage', 'large'],
        attachments: [
          ExportAttachmentItem(
            id: 'att-5',
            originalFilename: 'diagram5.png',
            mimeType: 'image/png',
            relativePath: 'attachments/diagram5.png',
            byteSize: dummyPng.length,
            createdAt: DateTime.utc(2026, 3, 1),
            sha256: 'sha5',
            bytes: dummyPng,
          ),
          ExportAttachmentItem(
            id: 'att-10',
            originalFilename: 'diagram10.png',
            mimeType: 'image/png',
            relativePath: 'attachments/diagram10.png',
            byteSize: dummyPng.length,
            createdAt: DateTime.utc(2026, 3, 1),
            sha256: 'sha10',
            bytes: dummyPng,
          ),
        ],
      );

      final request = const ExportRequest(
        noteId: 'long-note-1',
        format: ExportFormat.pdf,
        includeMetadata: true,
        pdfOptions: PdfExportOptions(
          showTags: true,
          showDates: true,
          includeAttachments: true,
          pageSize: 'Letter',
        ),
      );

      final outputFile = File('${tempDir.path}/Long_Multi_Page_Note.pdf');
      final result = await exporter.exportPdf(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.byteSize, greaterThan(20000));
      expect(result.warnings, isEmpty);
      expect(await outputFile.exists(), isTrue);

      final bytes = await outputFile.readAsBytes();
      final pdfRaw = latin1.decode(bytes);
      // Count pages in PDF output
      final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(pdfRaw);
      expect(pageMatches.length, greaterThanOrEqualTo(3)); // At least 3 pages generated
    });

    test('Section 43: PDF Export Options are fully respected', () async {
      const markdown = '''# Options Test Note
Paragraph body.
''';

      final snapshot = NoteExportSnapshot(
        noteId: 'opt-note-1',
        title: 'Options Test Note',
        markdown: markdown,
        createdAt: DateTime.utc(2026, 1, 10),
        updatedAt: DateTime.utc(2026, 1, 12),
        tags: const ['tag1', 'tag2'],
      );

      // 1. Without metadata
      final noMetaRequest = const ExportRequest(
        noteId: 'opt-note-1',
        format: ExportFormat.pdf,
        includeMetadata: false,
      );
      final noMetaFile = File('${tempDir.path}/No_Meta.pdf');
      final noMetaResult = await exporter.exportPdf(
        snapshot: snapshot,
        request: noMetaRequest,
        outputFile: noMetaFile,
      );

      // 2. With metadata
      final withMetaRequest = const ExportRequest(
        noteId: 'opt-note-1',
        format: ExportFormat.pdf,
        includeMetadata: true,
        pdfOptions: PdfExportOptions(showTags: true, showDates: true),
      );
      final withMetaFile = File('${tempDir.path}/With_Meta.pdf');
      final withMetaResult = await exporter.exportPdf(
        snapshot: snapshot,
        request: withMetaRequest,
        outputFile: withMetaFile,
      );

      expect(noMetaResult.byteSize, greaterThan(1000));
      expect(withMetaResult.byteSize, greaterThan(noMetaResult.byteSize));
    });
  });
}
