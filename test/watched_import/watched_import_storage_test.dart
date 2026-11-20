import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Uint8List, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/database/watched_import_schema.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/security/sensitive_preview_registry.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/email_import/application/email_parser.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/watched_import/application/canonical_import_adapter.dart';
import 'package:quitepaper/features/watched_import/data/watched_import_repository.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';
import '../attachments/attachment_service_test.dart' show MockKeyManager;

Candidate candidate(
  Uint8List bytes, {
  String name = 'message.eml',
  String folder = 'folder',
  String? job,
}) => Candidate(
  jobId: job ?? WatchedImportRepositoryAdapter.uuid.v4(),
  folderId: folder,
  relativePath: Uint8List.fromList(utf8.encode(name)),
  displayName: name,
  size: bytes.length,
  revision: 'revision-${sha256.convert(bytes)}',
  sha256: sha256.convert(bytes).toString(),
  format: name.split('.').last,
  generation: 1,
  initialInventory: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late WatchedImportRepositoryAdapter store;
  late NotesRepository notes;
  late CanonicalImportAdapter adapter;
  late AttachmentService attachments;
  late DocumentService documents;
  late EmailImportService email;
  late MockKeyManager keys;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qp-watched-storage-');
    db = AppDatabase(NativeDatabase(File('${dir.path}/db.sqlite')));
    store = WatchedImportRepositoryAdapter(db);
    notes = DriftNotesRepository(db);
    keys = MockKeyManager(
      masterKey: Uint8List.fromList(List.generate(32, (i) => i)),
    );
    attachments = AttachmentService(
      database: db,
      keyManager: keys,
      storage: AttachmentLocalStorage(
        customBaseDirectory: Directory('${dir.path}/assets'),
      ),
    );
    documents = DocumentService(
      database: db,
      keyManager: keys,
      storage: DocumentLocalStorage(
        customDocumentsDirectory: Directory('${dir.path}/documents'),
      ),
    );
    email = EmailImportService(
      database: db,
      repository: notes,
      attachments: attachments,
    );
    adapter = CanonicalImportAdapter(
      store: store,
      email: email,
      notes: notes,
      attachments: attachments,
      documents: documents,
    );
    await store.enroll(
      const RootInfo(canonicalPath: '/approved/root', identity: '1:2'),
      'vault-a',
    );
  });
  tearDown(() async {
    await db.close();
    AttachmentLocalStorage.purgeAllMemoryCache();
    await dir.delete(recursive: true);
  });
  Uint8List fixture() =>
      File('test/email_import/fixtures/mixed.eml').readAsBytesSync();

  test(
    'fresh schema, mandatory complete enrollment and durable baseline after rename',
    () async {
      expect(db.schemaVersion, 23);
      final f = (await store.folder())!;
      await expectLater(
        store.decide(f.read<String>('id'), false),
        throwsStateError,
      );
      final bytes = Uint8List.fromList(utf8.encode('preexisting'));
      final c = candidate(bytes, folder: f.read<String>('id'), name: 'old.txt');
      await store.baseline(c, f);
      await store.inventoryDone(f.read<String>('id'), null);
      await store.decide(f.read<String>('id'), false);
      expect(
        await store.isBaseline(
          candidate(bytes, folder: c.folderId, name: 'renamed.txt'),
        ),
        isTrue,
      );
      expect(await store.receipt('vault-a', c), isNull);
      expect(
        (await store.folder())!.read<String>('existing_policy'),
        'only_new',
      );
    },
  );
  test(
    'watched EML reuses manual conversion, original and encrypted MIME assets',
    () async {
      final bytes = fixture();
      final message = await const EmailParser().parse(bytes);
      final manual = await email.save(
        email: message,
        mode: EmailImportMode.editable,
        title: message.subject,
      );
      final c = candidate(bytes);
      final job = await store.reserve(c, 'vault-a');
      final watched = await adapter.import(
        c,
        job,
        bytes,
        isCurrent: () => true,
      );
      String normalize(String content) => content.replaceAll(
        RegExp(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}'),
        'UUID',
      );
      expect(normalize(watched.content), normalize(manual.content));
      expect(watched.title, manual.title);
      expect(watched.tags, manual.tags);
      expect(
        watched.importSources.single.sender,
        manual.importSources.single.sender,
      );
      expect(
        watched.importSources.single.messageId,
        manual.importSources.single.messageId,
      );
      final assets = await attachments.getAttachmentsForNote(watched.id);
      final original = assets.singleWhere(
        (a) => a.mimeType == 'message/rfc822',
      );
      expect(
        (await attachments.resolveAsset(original.id)).data,
        orderedEquals(bytes),
      );
      expect(
        (await store.receipt('vault-a', c))!.read<String>('note_id'),
        watched.id,
      );
      expect(
        await store.rows('SELECT * FROM email_import_preparations'),
        isEmpty,
      );
      expect(
        File('test/email_import/fixtures/mixed.eml').readAsBytesSync(),
        orderedEquals(bytes),
      );
    },
  );
  test(
    'receipt survives deletion, restart and lost ACK and isolates vaults',
    () async {
      final bytes = fixture();
      final c = candidate(bytes);
      final job = await store.reserve(c, 'vault-a');
      final note = await adapter.import(c, job, bytes, isCurrent: () => true);
      await notes.deletePermanently(note.id);
      expect(await store.receipt('vault-a', c), isNotNull);
      expect(await store.receipt('vault-b', c), isNull);
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/db.sqlite')));
      store = WatchedImportRepositoryAdapter(db);
      expect(
        (await store.receipt(
          'vault-a',
          candidate(bytes, name: 'copied.eml'),
        ))!.read<String>('note_id'),
        note.id,
      );
      expect(await db.getNoteWithTags(note.id), isNull);
      expect(
        (await store.reserve(c, 'vault-a')).read<String>('id'),
        job.read<String>('id'),
      );
    },
  );
  test(
    'unique receipt failure rolls back note, tags, FTS and cleans encrypted stages',
    () async {
      final bytes = fixture();
      final first = candidate(bytes);
      final j1 = await store.reserve(first, 'vault-a');
      await adapter.import(first, j1, bytes, isCurrent: () => true);
      final second = candidate(bytes, name: 'copy.eml');
      final j2 = await store.reserve(second, 'vault-a');
      final before = await store.rows('SELECT id FROM notes');
      final assets = await store.rows('SELECT id FROM attachments');
      // Existing receipt conflicts at the final commit, after canonical preparation.
      await expectLater(
        adapter.import(second, j2, bytes, isCurrent: () => true),
        throwsA(isA<EmailImportException>()),
      );
      expect((await store.rows('SELECT id FROM notes')).length, before.length);
      expect(
        (await store.rows('SELECT id FROM attachments')).length,
        assets.length,
      );
      expect(
        await db.getNoteWithTags(j2.read<String>('planned_note_id')),
        isNull,
      );
      expect(
        await store.rows('SELECT * FROM email_import_preparations'),
        isEmpty,
      );
    },
  );
  test(
    'security change during preparation leaves no note or receipt',
    () async {
      final bytes = fixture();
      final c = candidate(bytes);
      final job = await store.reserve(c, 'vault-a');
      var checks = 0;
      await expectLater(
        adapter.import(
          c,
          job,
          bytes,
          isCurrent: () {
            checks++;
            return checks < 2;
          },
        ),
        throwsA(isA<EmailImportException>()),
      );
      expect(await store.receipt('vault-a', c), isNull);
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      SensitivePreviewRegistry.invalidate();
    },
  );
  test(
    'Markdown frontmatter, text and PDF use canonical stores without OCR',
    () async {
      for (final entry in <String, String>{
        'note.md': '---\ntitle: Existing title\ntags: [work]\n---\nBody #tag\n',
        'plain.txt': 'Plain text\n',
        'paper.pdf': '%PDF-1.4\n1 0 obj << /Type /Page >> endobj\n%%EOF',
      }.entries) {
        final bytes = Uint8List.fromList(utf8.encode(entry.value));
        final c = candidate(bytes, name: entry.key);
        final job = await store.reserve(c, 'vault-a');
        final note = await adapter.import(c, job, bytes, isCurrent: () => true);
        if (entry.key.endsWith('.md')) {
          expect(note.title, 'Existing title');
          expect(note.content, entry.value);
          expect(note.tags, contains('work'));
        }
        if (entry.key.endsWith('.txt')) expect(note.content, entry.value);
        if (entry.key.endsWith('.pdf')) {
          expect(note.content, contains('qp://document/'));
          final docs = await db.getDocumentsForNote(note.id);
          expect(docs.single.ocrState, 'not_requested');
        }
      }
      expect(await store.rows('SELECT * FROM watched_import_stages'), isEmpty);
    },
  );
  test(
    'interrupted ciphertext without metadata is purged using its journal',
    () async {
      const id = '50b25772-a040-44b4-9e07-5da27c623fbd';
      final documentFile = File('${dir.path}/documents/$id.qpd');
      // Use canonical storage path instead of guessing layout.
      final storage = DocumentLocalStorage(
        customDocumentsDirectory: Directory('${dir.path}/documents'),
      );
      final path = await storage.saveEncryptedBytes(
        documentId: id,
        encryptedBytes: Uint8List.fromList([1, 2, 3]),
      );
      await store.write(
        "INSERT INTO watched_import_stages(asset_id,kind,job_id) VALUES (?,'document','job')",
        [id],
      );
      await adapter.recover();
      expect(await File(path).exists(), isFalse);
      expect(await documentFile.exists(), isFalse);
      expect(await store.rows('SELECT * FROM watched_import_stages'), isEmpty);
    },
  );
  test(
    'erase clears watcher state and receipts; ordinary removal retains receipts',
    () async {
      final bytes = fixture();
      final c = candidate(bytes);
      final job = await store.reserve(c, 'vault-a');
      await adapter.import(c, job, bytes, isCurrent: () => true);
      await store.removeFolder();
      expect(await store.receipt('vault-a', c), isNotNull);
      await db.eraseAllLocalVaultData();
      for (final table in watchedImportTables) {
        expect(await store.rows('SELECT * FROM $table'), isEmpty);
      }
    },
  );
  test(
    'upgrade from v22 preserves existing notes and creates local-only tables',
    () async {
      await store.write('CREATE TABLE retained_probe (value TEXT)');
      await store.write("INSERT INTO retained_probe VALUES ('retained')");
      for (final table in watchedImportTables) {
        await store.write('DROP TABLE $table');
      }
      await store.write('PRAGMA user_version=22');
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/db.sqlite')));
      store = WatchedImportRepositoryAdapter(db);
      expect(
        (await store.rows(
          'SELECT * FROM retained_probe',
        )).single.read<String>('value'),
        'retained',
      );
      for (final table in watchedImportTables) {
        expect(await store.rows('SELECT * FROM $table'), isEmpty);
      }
    },
  );
}
