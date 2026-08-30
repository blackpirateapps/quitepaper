import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/text/attachment_note_creator.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AttachmentNoteCreator Tests', () {
    test('creates note from Markdown attachment with frontmatter title and tags', () async {
      final mdContent = '''---
title: My Imported Article
tags:
  - research
  - deepmind
---

# My Imported Article

This is the main article content.
''';
      final rawBytes = Uint8List.fromList(utf8.encode(mdContent));

      final attachment = AttachmentEntity(
        id: 'att-1',
        fileName: 'article.md',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'text/markdown',
        byteSize: rawBytes.length,
        sha256: 'hash-1',
        encryptionKeyVersion: 1,
        serverRevision: 0,
        isDirty: false,
        isDeleted: false,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final note = await AttachmentNoteCreator.createNoteFromAttachment(
        notesRepository: repository,
        attachment: attachment,
        rawBytes: rawBytes,
      );

      expect(note.title, 'My Imported Article');
      expect(note.content, mdContent);
      expect(note.tags, containsAll(['research', 'deepmind']));

      // Verify saved in repository
      final fetched = await repository.getNoteById(note.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'My Imported Article');
    });

    test('creates note from plain text attachment using filename as fallback title', () async {
      final textContent = 'Server logs and error traces\nError on line 42';
      final rawBytes = Uint8List.fromList(utf8.encode(textContent));

      final attachment = AttachmentEntity(
        id: 'att-2',
        fileName: 'server_diagnostics.txt',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'text/plain',
        byteSize: rawBytes.length,
        sha256: 'hash-2',
        encryptionKeyVersion: 1,
        serverRevision: 0,
        isDirty: false,
        isDeleted: false,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final note = await AttachmentNoteCreator.createNoteFromAttachment(
        notesRepository: repository,
        attachment: attachment,
        rawBytes: rawBytes,
      );

      expect(note.title, 'server_diagnostics');
      expect(note.content, textContent);
    });

    test('converts CSV attachment to Markdown table note', () async {
      final csvContent = 'Item,Count,Status\nKeyboard,2,Ready\nMonitor,1,Shipped';
      final rawBytes = Uint8List.fromList(utf8.encode(csvContent));

      final attachment = AttachmentEntity(
        id: 'att-3',
        fileName: 'inventory.csv',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'text/csv',
        byteSize: rawBytes.length,
        sha256: 'hash-3',
        encryptionKeyVersion: 1,
        serverRevision: 0,
        isDirty: false,
        isDeleted: false,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final note = await AttachmentNoteCreator.createNoteFromAttachment(
        notesRepository: repository,
        attachment: attachment,
        rawBytes: rawBytes,
      );

      expect(note.title, 'inventory');
      expect(note.content.contains('| Item | Count | Status |'), isTrue);
      expect(note.content.contains('| --- | --- | --- |'), isTrue);
      expect(note.content.contains('| Keyboard | 2 | Ready |'), isTrue);
    });

    test('wraps source code files in code block with language identifier', () async {
      final dartCode = 'void main() {\n  print("Hello Quiet Paper");\n}\n';
      final rawBytes = Uint8List.fromList(utf8.encode(dartCode));

      final attachment = AttachmentEntity(
        id: 'att-4',
        fileName: 'main.dart',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'application/vnd.dart',
        byteSize: rawBytes.length,
        sha256: 'hash-4',
        encryptionKeyVersion: 1,
        serverRevision: 0,
        isDirty: false,
        isDeleted: false,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final note = await AttachmentNoteCreator.createNoteFromAttachment(
        notesRepository: repository,
        attachment: attachment,
        rawBytes: rawBytes,
      );

      expect(note.title, 'main');
      expect(note.content.startsWith('```dart\n'), isTrue);
      expect(note.content.contains('void main()'), isTrue);
      expect(note.content.endsWith('\n```'), isTrue);
    });

    test('enforces 5 MB size limit on note creation', () async {
      // 6 MB payload
      final hugeBytes = Uint8List(6 * 1024 * 1024);

      final attachment = AttachmentEntity(
        id: 'att-huge',
        fileName: 'huge.txt',
        kind: 'file',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        mimeType: 'text/plain',
        byteSize: hugeBytes.length,
        sha256: 'hash-huge',
        encryptionKeyVersion: 1,
        serverRevision: 0,
        isDirty: false,
        isDeleted: false,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      expect(
        () => AttachmentNoteCreator.createNoteFromAttachment(
          notesRepository: repository,
          attachment: attachment,
          rawBytes: hugeBytes,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
