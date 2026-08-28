import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/features/export/application/exporters/markdown_exporter.dart';
import 'package:quitepaper/features/export/application/exporters/plain_text_exporter.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

void main() {
  group('MarkdownExporter', () {
    const exporter = MarkdownExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('md_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('exports canonical markdown body without metadata when disabled', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Simple Note',
        markdown: '# Title\n- [ ] Task 1\n- [x] Task 2\n\n```dart\nvoid main() {}\n```',
        createdAt: DateTime.utc(2026, 3, 15, 10, 0),
        updatedAt: DateTime.utc(2026, 3, 15, 12, 0),
        tags: const ['tech', 'todo'],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.markdown,
        includeMetadata: false,
      );

      final outputFile = File('${tempDir.path}/Simple Note.md');
      final result = await exporter.exportMarkdown(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.markdown));
      expect(result.byteSize, greaterThan(0));

      final text = await outputFile.readAsString();
      expect(text, isNot(startsWith('---')));
      expect(text, contains('# Title'));
      expect(text, contains('- [ ] Task 1'));
      expect(text, contains('- [x] Task 2'));
      expect(text, contains('```dart'));
    });

    test('prepends YAML frontmatter when includeMetadata is true', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Meeting Notes',
        markdown: 'Discussed project scope.',
        createdAt: DateTime.utc(2026, 3, 15, 10, 0),
        updatedAt: DateTime.utc(2026, 3, 15, 12, 0),
        isPinned: true,
        tags: const ['work', 'q1'],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.markdown,
        includeMetadata: true,
      );

      final outputFile = File('${tempDir.path}/Meeting Notes.md');
      await exporter.exportMarkdown(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      final text = await outputFile.readAsString();
      expect(text, startsWith('---'));
      expect(text, contains('title: "Meeting Notes"'));
      expect(text, contains('pinned: true'));
      expect(text, contains('tags:'));
      expect(text, contains('  - work'));
      expect(text, contains('  - q1'));
      expect(text, contains('Discussed project scope.'));
    });

    test('appends OCR transcript when configured', () async {
      final ocrDoc = OcrDocument(
        documentId: 'doc1',
        language: OcrLanguage.english,
        engine: 'test',
        engineVersion: '1.0',
        schemaVersion: 1,
        processedAt: DateTime.utc(2026, 1, 1),
        sourceDocumentSha256: 'abc',
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Scanned receipt total: \$50.00',
            width: 800,
            height: 1200,
          ),
        ],
      );

      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Receipt',
        markdown: 'Note content.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        ocrData: [
          ExportOcrItem(
            resourceId: 'doc1',
            resourceType: 'document',
            document: ocrDoc,
          ),
        ],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.markdown,
        includeOcr: true,
        ocrStrategy: OcrExportStrategy.appendToDocument,
      );

      final outputFile = File('${tempDir.path}/Receipt.md');
      await exporter.exportMarkdown(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      final text = await outputFile.readAsString();
      expect(text, contains('## Document OCR Transcripts'));
      expect(text, contains('Scanned receipt total: \$50.00'));
    });
  });

  group('PlainTextExporter', () {
    const exporter = PlainTextExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('txt_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('converts markdown syntax to clean readable plain text', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Project Tasks',
        markdown: '''# Main Title
## Section
- [ ] Incomplete item
- [x] Completed item
- Bullet item 1
- Bullet item 2

> This is an important quote.

Here is **bold text**, *italic text*, and ~~strikethrough~~.

![Diagram](attachments/diagram.png)
[Google](https://google.com)
''',
        createdAt: DateTime.utc(2026, 3, 15, 10, 0),
        updatedAt: DateTime.utc(2026, 3, 15, 12, 0),
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.plainText,
        includeMetadata: false,
      );

      final outputFile = File('${tempDir.path}/Project Tasks.txt');
      final result = await exporter.exportPlainText(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.plainText));
      final text = await outputFile.readAsString();

      // Check headings stripped
      expect(text, contains('Main Title'));
      expect(text, isNot(contains('# Main Title')));

      // Check tasks converted
      expect(text, contains('☐ Incomplete item'));
      expect(text, contains('☑ Completed item'));

      // Check bullets
      expect(text, contains('• Bullet item 1'));

      // Check quotes
      expect(text, contains('| This is an important quote.'));

      // Check styles stripped
      expect(text, contains('Here is bold text, italic text, and strikethrough.'));

      // Check images & links
      expect(text, contains('[Image: Diagram]'));
      expect(text, contains('Google (https://google.com)'));
    });
  });
}
