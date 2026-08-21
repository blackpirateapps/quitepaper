import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/core/database/app_database.dart';

void main() {
  late Directory tempDir;
  var dbCounter = 0;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tempDir = await Directory.systemTemp.createTemp('quitepaper_migration_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File getNextDbFile() {
    dbCounter++;
    return File(p.join(tempDir.path, 'migration_test_$dbCounter.db'));
  }

  group('Database Schema Migration Tests', () {
    test('Upgrade from Schema v1 to v8', () async {
      final dbFile = getNextDbFile();
      final setupDb = NativeDatabase(dbFile);
      // Setup v1 schema: notes (basic), tags, note_tags
      await setupDb.ensureOpen(_FakeDbUser(1));
      await setupDb.runCustom('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        );
        CREATE TABLE note_tags (
          note_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (note_id, tag_id)
        );
        PRAGMA user_version = 1;
      ''');
      await setupDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      // Trigger migration by running a query
      final notes = await db.watchNotes().first;
      expect(notes, isEmpty);

      // Verify documents table exists and has source column
      const docId = 'doc-v1-test';
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              id: docId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final doc = await (db.select(db.documentsTable)
            ..where((d) => d.id.equals(docId)))
          .getSingle();
      expect(doc.source, 'scanner');
      expect(doc.ocrState, 'not_requested');

      await db.close();
    });

    test('Upgrade from Schema v5 to v8 (note_versions exists, documents does not exist)', () async {
      final dbFile = getNextDbFile();
      final setupDb = NativeDatabase(dbFile);
      // Setup v5 schema
      await setupDb.ensureOpen(_FakeDbUser(5));
      await setupDb.runCustom('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_trashed INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        );
        CREATE TABLE note_tags (
          note_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (note_id, tag_id)
        );
        CREATE TABLE sync_metadata (
          "key" TEXT NOT NULL PRIMARY KEY,
          "value" TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE sync_queue (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        );
        CREATE TABLE attachments (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          mime_type TEXT NOT NULL DEFAULT 'image/png',
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          sha256 TEXT NOT NULL DEFAULT '',
          encryption_key_version INTEGER NOT NULL DEFAULT 1,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          synced_at INTEGER,
          upload_state TEXT NOT NULL DEFAULT 'local_only',
          cloud_public_id TEXT,
          cloud_url TEXT,
          local_path TEXT
        );
        CREATE TABLE attachment_variants (
          id TEXT NOT NULL PRIMARY KEY,
          attachment_id TEXT NOT NULL,
          variant_type TEXT NOT NULL,
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          local_path TEXT,
          cloud_public_id TEXT,
          cloud_url TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE note_versions (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          version_number INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          content TEXT NOT NULL DEFAULT '',
          tags_json TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL,
          char_count INTEGER NOT NULL DEFAULT 0,
          word_count INTEGER NOT NULL DEFAULT 0,
          delta_summary TEXT,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        PRAGMA user_version = 5;
      ''');
      await setupDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      // Trigger migration
      final notes = await db.watchNotes().first;
      expect(notes, isEmpty);

      // Verify documents table created properly with source column
      const docId = 'doc-v5-test';
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              id: docId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final doc = await (db.select(db.documentsTable)
            ..where((d) => d.id.equals(docId)))
          .getSingle();
      expect(doc.source, 'scanner');

      // Verify note_versions has the upgraded provenance columns
      const versionId = 'ver-v5-test';
      await db.into(db.noteVersionsTable).insert(
            NoteVersionsTableCompanion.insert(
              id: versionId,
              noteId: 'n1',
              versionNumber: 1,
              createdAt: DateTime.now(),
              baseRevision: const Value(10),
              mergeType: const Value('3way_auto'),
            ),
          );
      final ver = await (db.select(db.noteVersionsTable)
            ..where((v) => v.id.equals(versionId)))
          .getSingle();
      expect(ver.baseRevision, 10);
      expect(ver.mergeType, '3way_auto');

      await db.close();
    });

    test('Upgrade from Schema v6 to v8 (documents table exists without source/ocrState)', () async {
      final dbFile = getNextDbFile();
      final setupDb = NativeDatabase(dbFile);
      // Setup v6 schema where documents has no source/ocrState/ocrLanguage
      await setupDb.ensureOpen(_FakeDbUser(6));
      await setupDb.runCustom('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_trashed INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        );
        CREATE TABLE note_tags (
          note_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (note_id, tag_id)
        );
        CREATE TABLE sync_metadata (
          "key" TEXT NOT NULL PRIMARY KEY,
          "value" TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE sync_queue (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        );
        CREATE TABLE attachments (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          mime_type TEXT NOT NULL DEFAULT 'image/png',
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          sha256 TEXT NOT NULL DEFAULT '',
          encryption_key_version INTEGER NOT NULL DEFAULT 1,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          synced_at INTEGER,
          upload_state TEXT NOT NULL DEFAULT 'local_only',
          cloud_public_id TEXT,
          cloud_url TEXT,
          local_path TEXT
        );
        CREATE TABLE attachment_variants (
          id TEXT NOT NULL PRIMARY KEY,
          attachment_id TEXT NOT NULL,
          variant_type TEXT NOT NULL,
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          local_path TEXT,
          cloud_public_id TEXT,
          cloud_url TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE note_versions (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          version_number INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          content TEXT NOT NULL DEFAULT '',
          tags_json TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL,
          char_count INTEGER NOT NULL DEFAULT 0,
          word_count INTEGER NOT NULL DEFAULT 0,
          delta_summary TEXT,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        CREATE TABLE documents (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT,
          title TEXT NOT NULL DEFAULT 'Scanned Document',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          mime_type TEXT NOT NULL DEFAULT 'application/pdf',
          byte_size INTEGER NOT NULL DEFAULT 0,
          page_count INTEGER NOT NULL DEFAULT 1,
          sha256 TEXT NOT NULL DEFAULT '',
          encryption_key_version INTEGER NOT NULL DEFAULT 1,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          synced_at INTEGER,
          upload_state TEXT NOT NULL DEFAULT 'local_only',
          cloud_public_id TEXT,
          cloud_url TEXT,
          local_path TEXT,
          thumbnail_path TEXT
        );
        PRAGMA user_version = 6;
      ''');
      await setupDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      // Trigger migration
      final notes = await db.watchNotes().first;
      expect(notes, isEmpty);

      // Verify documents table had source column added smoothly
      const docId = 'doc-v6-test';
      await db.into(db.documentsTable).insert(
            DocumentsTableCompanion.insert(
              id: docId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      final doc = await (db.select(db.documentsTable)
            ..where((d) => d.id.equals(docId)))
          .getSingle();
      expect(doc.source, 'scanner');
      expect(doc.ocrState, 'not_requested');
      expect(doc.ocrLanguage, 'en');

      await db.close();
    });

    test('Upgrade from Schema v7 to v8', () async {
      final dbFile = getNextDbFile();
      final setupDb = NativeDatabase(dbFile);
      await setupDb.ensureOpen(_FakeDbUser(7));
      await setupDb.runCustom('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_trashed INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE
        );
        CREATE TABLE note_tags (
          note_id TEXT NOT NULL,
          tag_id TEXT NOT NULL,
          PRIMARY KEY (note_id, tag_id)
        );
        CREATE TABLE sync_metadata (
          "key" TEXT NOT NULL PRIMARY KEY,
          "value" TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        );
        CREATE TABLE sync_queue (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        );
        CREATE TABLE attachments (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          mime_type TEXT NOT NULL DEFAULT 'image/png',
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          sha256 TEXT NOT NULL DEFAULT '',
          encryption_key_version INTEGER NOT NULL DEFAULT 1,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          synced_at INTEGER,
          upload_state TEXT NOT NULL DEFAULT 'local_only',
          cloud_public_id TEXT,
          cloud_url TEXT,
          local_path TEXT
        );
        CREATE TABLE attachment_variants (
          id TEXT NOT NULL PRIMARY KEY,
          attachment_id TEXT NOT NULL,
          variant_type TEXT NOT NULL,
          byte_size INTEGER NOT NULL DEFAULT 0,
          width INTEGER,
          height INTEGER,
          local_path TEXT,
          cloud_public_id TEXT,
          cloud_url TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE note_versions (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT NOT NULL,
          version_number INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          content TEXT NOT NULL DEFAULT '',
          tags_json TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL,
          char_count INTEGER NOT NULL DEFAULT 0,
          word_count INTEGER NOT NULL DEFAULT 0,
          delta_summary TEXT,
          server_revision INTEGER NOT NULL DEFAULT 0,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER
        );
        CREATE TABLE documents (
          id TEXT NOT NULL PRIMARY KEY,
          note_id TEXT,
          title TEXT NOT NULL DEFAULT 'Scanned Document',
          source TEXT NOT NULL DEFAULT 'scanner',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          mime_type TEXT NOT NULL DEFAULT 'application/pdf',
          byte_size INTEGER NOT NULL DEFAULT 0,
          page_count INTEGER NOT NULL DEFAULT 1,
          sha256 TEXT NOT NULL DEFAULT '',
          encryption_key_version INTEGER NOT NULL DEFAULT 1,
          is_dirty INTEGER NOT NULL DEFAULT 1,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          server_revision INTEGER NOT NULL DEFAULT 0,
          synced_at INTEGER,
          upload_state TEXT NOT NULL DEFAULT 'local_only',
          cloud_public_id TEXT,
          cloud_url TEXT,
          local_path TEXT,
          thumbnail_path TEXT,
          ocr_state TEXT NOT NULL DEFAULT 'not_requested',
          ocr_language TEXT NOT NULL DEFAULT 'en'
        );
        CREATE TABLE document_ocr_pages (
          document_id TEXT NOT NULL,
          page_number INTEGER NOT NULL,
          encrypted_payload TEXT NOT NULL,
          ocr_schema_version INTEGER NOT NULL DEFAULT 1,
          ocr_engine TEXT NOT NULL DEFAULT 'google_mlkit',
          ocr_engine_version TEXT NOT NULL DEFAULT 'v1',
          language TEXT NOT NULL DEFAULT 'en',
          processed_at INTEGER NOT NULL,
          PRIMARY KEY (document_id, page_number)
        );
        PRAGMA user_version = 7;
      ''');
      await setupDb.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      // Trigger migration
      final notes = await db.watchNotes().first;
      expect(notes, isEmpty);

      // Verify sync_conflicts table exists
      final count = await (db.selectOnly(db.syncConflictsTable)
            ..addColumns([db.syncConflictsTable.id.count()]))
          .getSingle();
      expect(count.read(db.syncConflictsTable.id.count()), 0);

      await db.close();
    });
  });
}

class _FakeDbUser extends QueryExecutorUser {
  _FakeDbUser(this.version);
  final int version;

  @override
  int get schemaVersion => version;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
