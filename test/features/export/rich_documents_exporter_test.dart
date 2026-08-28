import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/export/application/exporters/docx_exporter.dart';
import 'package:quitepaper/features/export/application/exporters/html_exporter.dart';
import 'package:quitepaper/features/export/application/exporters/pdf_exporter.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

void main() {
  group('HtmlExporter', () {
    const exporter = HtmlExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('html_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates valid standalone HTML5 document with styling', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Weekly Standup',
        markdown: '''# Agenda
- [x] Review metrics
- [ ] Plan sprints

==Highlight this crucial point==

```dart
final x = 42;
```
''',
        createdAt: DateTime.utc(2026, 3, 10),
        updatedAt: DateTime.utc(2026, 3, 11),
        tags: const ['meeting', 'team'],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.html,
        includeMetadata: true,
      );

      final outputFile = File('${tempDir.path}/Weekly Standup.html');
      final result = await exporter.exportHtml(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.html));
      final html = await outputFile.readAsString();

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<html lang="en">'));
      expect(html, contains('<title>Weekly Standup</title>'));
      expect(html, contains('class="note-title">Weekly Standup</h1>'));
      expect(html, contains('class="tag-chip">#meeting</span>'));
      expect(html, contains('class="highlight">Highlight this crucial point</mark>'));
      expect(html, contains('final x = 42;'));
      expect(html, contains('</html>'));
    });

    test('embeds image attachments as base64 data URIs', () async {
      // 1x1 transparent PNG bytes
      final dummyPng = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Image Note',
        markdown: '![Chart](attachments/chart.png)',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        attachments: [
          ExportAttachmentItem(
            id: 'att-1',
            originalFilename: 'chart.png',
            mimeType: 'image/png',
            relativePath: 'attachments/chart.png',
            byteSize: dummyPng.length,
            createdAt: DateTime.utc(2026, 1, 1),
            sha256: 'abc123',
            bytes: dummyPng,
          ),
        ],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.html,
        htmlOptions: HtmlExportOptions(embedImagesAsBase64: true),
      );

      final outputFile = File('${tempDir.path}/Image Note.html');
      await exporter.exportHtml(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      final html = await outputFile.readAsString();
      expect(html, contains('data:image/png;base64,'));
    });
  });

  group('PdfExporter', () {
    const exporter = PdfExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates valid vector PDF with headings, lists, code, and metadata', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Architectural Decisions',
        markdown: '''# System Design
This document outlines our local-first offline architecture.

## Requirements
- [x] Zero network dependency
- [ ] Real-time sync engine
- High performance Drift SQLite

> "Simplicity is prerequisite for reliability."

```dart
class Engine {
  void start() => print('Started');
}
```
''',
        createdAt: DateTime.utc(2026, 2, 20),
        updatedAt: DateTime.utc(2026, 2, 22),
        tags: const ['architecture', 'offline-first'],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.pdf,
        includeMetadata: true,
      );

      final outputFile = File('${tempDir.path}/Architectural Decisions.pdf');
      final result = await exporter.exportPdf(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.pdf));
      expect(result.byteSize, greaterThan(1000));

      final bytes = await outputFile.readAsBytes();
      // PDF header verification (%PDF-)
      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });

  group('DocxExporter', () {
    const exporter = DocxExporter();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('docx_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates valid Microsoft Word OpenXML (.docx) package', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'n1',
        title: 'Project Proposal',
        markdown: '''# Proposal Overview
This proposal covers the new export feature set.

## Scope
- [x] Markdown export
- [x] PDF export
- [ ] Webhook sync

> Important timeline note.

```sql
SELECT * FROM notes WHERE is_archived = 0;
```
''',
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 2),
        tags: const ['proposal', 'q2'],
      );

      final request = const ExportRequest(
        noteId: 'n1',
        format: ExportFormat.docx,
        includeMetadata: true,
      );

      final outputFile = File('${tempDir.path}/Project Proposal.docx');
      final result = await exporter.exportDocx(
        snapshot: snapshot,
        request: request,
        outputFile: outputFile,
      );

      expect(result.format, equals(ExportFormat.docx));
      expect(result.byteSize, greaterThan(500));

      // Inspect DOCX ZIP contents
      final bytes = await outputFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.map((f) => f.name).toSet();
      expect(fileNames, contains('[Content_Types].xml'));
      expect(fileNames, contains('_rels/.rels'));
      expect(fileNames, contains('word/_rels/document.xml.rels'));
      expect(fileNames, contains('word/styles.xml'));
      expect(fileNames, contains('word/document.xml'));

      final docXmlFile = archive.firstWhere((f) => f.name == 'word/document.xml');
      final docXml = utf8.decode(docXmlFile.content as List<int>);
      expect(docXml, contains('Project Proposal'));
      expect(docXml, contains('Proposal Overview'));
      expect(docXml, contains('Markdown export'));
      expect(docXml, contains('Webhook sync'));
      expect(docXml, contains('☑'));
      expect(docXml, contains('☐'));
    });
  });
}
