import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/features/export/application/exporters/qpnote_exporter.dart';
import 'package:quitepaper/features/export/application/qpnote_validator.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

void main() {
  group('QpNotePackageExporter & QpNoteValidator', () {
    late QpNotePackageExporter exporter;
    late QpNoteValidator validator;
    late Directory tempDir;

    setUp(() async {
      exporter = QpNotePackageExporter();
      validator = QpNoteValidator();
      tempDir = await Directory.systemTemp.createTemp('qpnote_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates full fidelity .qpnote package with valid manifest, metadata, attachments, and OCR', () async {
      final dummyImgBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final dummyPdfBytes = Uint8List.fromList([10, 20, 30, 40, 50]);

      final ocrDoc = OcrDocument(
        documentId: 'doc-1',
        language: OcrLanguage.english,
        engine: 'quietpaper_ocr_v1',
        engineVersion: '1.0.0',
        schemaVersion: 1,
        processedAt: DateTime.utc(2026, 1, 1),
        sourceDocumentSha256: 'sha-dummy',
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Scanned text page 1',
            width: 800,
            height: 1000,
          ),
          OcrPage(
            pageNumber: 2,
            plainText: 'Scanned text page 2',
            width: 800,
            height: 1000,
          ),
        ],
      );

      final snapshot = NoteExportSnapshot(
        noteId: 'test-note-123',
        title: 'Project Blueprint',
        markdown: '# Project Blueprint\n\n![Diagram](attachments/diagram.png)\n[PDF Spec](attachments/spec.pdf)',
        createdAt: DateTime.utc(2026, 1, 10, 10, 0),
        updatedAt: DateTime.utc(2026, 1, 12, 15, 30),
        isPinned: true,
        tags: const ['engineering', 'spec'],
        attachments: [
          ExportAttachmentItem(
            id: 'att-1',
            originalFilename: 'diagram.png',
            mimeType: 'image/png',
            relativePath: 'attachments/diagram.png',
            byteSize: dummyImgBytes.length,
            createdAt: DateTime.utc(2026, 1, 10),
            sha256: '',
            bytes: dummyImgBytes,
          ),
        ],
        documents: [
          ExportDocumentItem(
            id: 'doc-1',
            title: 'Technical Specification',
            mimeType: 'application/pdf',
            relativePath: 'attachments/spec.pdf',
            byteSize: dummyPdfBytes.length,
            pageCount: 2,
            createdAt: DateTime.utc(2026, 1, 10),
            sha256: '',
            bytes: dummyPdfBytes,
          ),
        ],
        ocrData: [
          ExportOcrItem(
            resourceId: 'doc-1',
            resourceType: 'document',
            document: ocrDoc,
            relativePath: 'ocr/doc_doc-1',
          ),
        ],
      );

      final request = const ExportRequest(
        noteId: 'test-note-123',
        format: ExportFormat.qpnote,
        includeMetadata: true,
        includeAttachments: true,
        includeOcr: true,
        ocrStrategy: OcrExportStrategy.separateFiles,
        packageOptions: QpNoteExportOptions(
          includeMetadata: true,
          includeAttachments: true,
          includeOcr: true,
          preserveIds: true,
        ),
      );

      final packageFile = File('${tempDir.path}/Project Blueprint.qpnote');
      final result = await exporter.exportQpNote(
        snapshot: snapshot,
        request: request,
        outputFile: packageFile,
      );

      expect(result.format, equals(ExportFormat.qpnote));
      expect(await packageFile.exists(), isTrue);

      // Validate with QpNoteValidator
      final validation = await validator.validatePackageFile(packageFile);
      expect(validation.isValid, isTrue);
      expect(validation.isEncrypted, isFalse);
      expect(validation.formatVersion, equals(1));
      expect(validation.noteTitle, equals('Project Blueprint'));
      expect(validation.noteId, equals('test-note-123'));
      expect(validation.totalAttachments, equals(1));
      expect(validation.totalDocuments, equals(1));
      expect(validation.totalOcrDatasets, equals(1));
      expect(validation.errors, isEmpty);
    });

    test('detects missing manifest in corrupted archive', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('note.md', 5, utf8.encode('Hello')));

      final zipBytes = ZipEncoder().encode(archive);
      final corruptedFile = File('${tempDir.path}/corrupted.qpnote');
      await corruptedFile.writeAsBytes(zipBytes);

      final validation = await validator.validatePackageFile(corruptedFile);
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains(contains('Missing required manifest.json')));
    });

    test('detects path traversal attack in malicious package', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile('../evil.sh', 5, utf8.encode('echo 1')));
      archive.addFile(ArchiveFile('manifest.json', 2, utf8.encode('{}')));

      final zipBytes = ZipEncoder().encode(archive);
      final maliciousFile = File('${tempDir.path}/malicious.qpnote');
      await maliciousFile.writeAsBytes(zipBytes);

      final validation = await validator.validatePackageFile(maliciousFile);
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains(contains('Security violation')));
    });

    test('detects SHA-256 integrity hash mismatch', () async {
      final archive = Archive();
      final badMarkdown = utf8.encode('Altered content');
      archive.addFile(ArchiveFile('note.md', badMarkdown.length, badMarkdown));
      archive.addFile(ArchiveFile('metadata.json', 2, utf8.encode('{}')));

      final manifest = {
        'format': 'quietpaper:note:v1',
        'version': 1,
        'content': {
          'markdown': 'note.md',
          'sha256': 'wrong_sha_hash_value',
        },
        'metadata': {'path': 'metadata.json'},
      };
      final manifestBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      final zipBytes = ZipEncoder().encode(archive);
      final tamperedFile = File('${tempDir.path}/tampered.qpnote');
      await tamperedFile.writeAsBytes(zipBytes);

      final validation = await validator.validatePackageFile(tamperedFile);
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains(contains('SHA-256 integrity verification failed')));
    });

    test('encrypts and decrypts package with password', () async {
      final snapshot = NoteExportSnapshot(
        noteId: 'enc-note-1',
        title: 'Secret Blueprint',
        markdown: '# Secret Blueprint\nConfidential instructions.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        tags: const ['confidential'],
      );

      final request = const ExportRequest(
        noteId: 'enc-note-1',
        format: ExportFormat.qpnote,
        packageOptions: QpNoteExportOptions(
          isEncrypted: true,
          packagePassword: 'super_secret_password',
        ),
      );

      final packageFile = File('${tempDir.path}/Secret Blueprint.qpnote');
      await exporter.exportQpNote(
        snapshot: snapshot,
        request: request,
        outputFile: packageFile,
      );

      // Validate without password -> identifies encrypted status
      final validationWithoutPass = await validator.validatePackageFile(packageFile);
      expect(validationWithoutPass.isValid, isTrue);
      expect(validationWithoutPass.isEncrypted, isTrue);
      expect(validationWithoutPass.noteTitle, equals('Secret Blueprint'));

      // Validate with correct password -> inspects inner contents
      final validationWithPass = await validator.validatePackageFile(
        packageFile,
        packagePassword: 'super_secret_password',
      );
      expect(validationWithPass.isValid, isTrue);
      expect(validationWithPass.errors, isEmpty);

      // Validate with incorrect password -> fails decryption
      final validationWrongPass = await validator.validatePackageFile(
        packageFile,
        packagePassword: 'wrong_password',
      );
      expect(validationWrongPass.isValid, isFalse);
      expect(validationWrongPass.errors, contains(contains('Incorrect package password')));
    });
  });
}
