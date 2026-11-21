import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/features/watched_import/presentation/reveal_watched_source.dart';
import 'package:quitepaper/features/import/application/markdown_image_parser.dart';
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
    'PNG, JPEG and WebP are encrypted with canonical links and no OCR',
    () async {
      for (final format in ['png', 'jpg', 'jpeg', 'webp']) {
        final bytes = File(
          'test/watched_import/fixtures/pixel.${format == 'jpeg' ? 'jpg' : format}',
        ).readAsBytesSync();
        final c = candidate(bytes, name: 'pixel.$format');
        final job = await store.reserve(c, 'image-$format');
        final note = await adapter.import(c, job, bytes, isCurrent: () => true);
        expect(note.content, contains('qp://asset/'));
        final asset = (await attachments.getAttachmentsForNote(note.id)).single;
        expect(asset.ocrState, 'not_requested');
        expect(asset.isDirty, isTrue);
        expect(
          (await attachments.resolveAsset(asset.id)).data,
          orderedEquals(bytes),
        );
        expect(
          await File(asset.localPath!).readAsBytes(),
          isNot(orderedEquals(bytes)),
        );
      }
    },
  );
  test(
    'Markdown local images reuse parser/rewrite and staged assets atomically',
    () async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          '---\ntitle: Image note\n---\n![Alt](images/pixel.png)\n\n![[images/pixel.png|Alt]]\n',
        ),
      );
      final c = candidate(bytes, name: 'note.md');
      final job = await store.reserve(c, 'vault-a');
      final png = File(
        'test/watched_import/fixtures/pixel.png',
      ).readAsBytesSync();
      var reads = 0;
      final note = await adapter.import(
        c,
        job,
        bytes,
        isCurrent: () => true,
        readRelatedImage: (target) async {
          expect(target, 'images/pixel.png');
          reads++;
          return png;
        },
      );
      expect(reads, 1);
      expect(note.content, contains('qp://asset/'));
      expect(note.content, contains('title: Image note'));
      expect(note.content, contains('![Alt]'));
      expect((await attachments.getAttachmentsForNote(note.id)).length, 1);
      expect(await store.rows('SELECT * FROM watched_import_stages'), isEmpty);
    },
  );
  test(
    'missing Markdown image refuses receipt and purges earlier stages',
    () async {
      final bytes = Uint8List.fromList(
        utf8.encode('![One](first.png)\n![Missing](missing.png)'),
      );
      final c = candidate(bytes, name: 'note.md');
      final job = await store.reserve(c, 'vault-a');
      final png = File(
        'test/watched_import/fixtures/pixel.png',
      ).readAsBytesSync();
      await expectLater(
        adapter.import(
          c,
          job,
          bytes,
          isCurrent: () => true,
          readRelatedImage: (target) async {
            if (target == 'first.png') return png;
            throw StateError('missing');
          },
        ),
        throwsA(isA<EmailImportException>()),
      );
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      expect(await store.receipt('vault-a', c), isNull);
      expect(await store.rows('SELECT * FROM attachments'), isEmpty);
      expect(await store.rows('SELECT * FROM watched_import_stages'), isEmpty);
    },
  );
  test(
    'backup v1 restores notes without watcher paths, scope or activation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bytes = Uint8List.fromList(utf8.encode('backup content'));
      final c = candidate(bytes, name: 'backup.txt');
      final job = await store.reserve(c, 'vault-a');
      final note = await adapter.import(c, job, bytes, isCurrent: () => true);
      final backup = BackupService(
        database: db,
        cryptoService: DefaultCryptoService(),
        sharedPreferences: prefs,
      );
      final payload = await backup.generateBackupPayload();
      final serialized = jsonEncode(payload.toJson());
      expect(serialized, contains('backup content'));
      expect(serialized, isNot(contains('/approved/root')));
      expect(serialized, isNot(contains('watched_import')));
      final restored = AppDatabase.memory();
      try {
        await BackupService(
          database: restored,
          cryptoService: DefaultCryptoService(),
          sharedPreferences: prefs,
        ).restoreBackup(payload);
        final local = WatchedImportRepositoryAdapter(restored);
        expect(await local.folder(), isNull);
        expect(
          await local.rows('SELECT * FROM watched_import_receipts'),
          isEmpty,
        );
        expect(
          (await DriftNotesRepository(restored).getNoteById(note.id))!.content,
          note.content,
        );
      } finally {
        await restored.close();
      }
    },
  );
  test(
    'early schema-23 layouts retain state while source provenance columns appear',
    () async {
      await store.write(
        'ALTER TABLE watched_import_jobs DROP COLUMN source_root',
      );
      await store.write(
        'ALTER TABLE watched_import_receipts DROP COLUMN source_root',
      );
      await store.write(
        'ALTER TABLE watched_import_receipts DROP COLUMN source_path',
      );
      await db.close();
      db = AppDatabase(NativeDatabase(File('${dir.path}/db.sqlite')));
      store = WatchedImportRepositoryAdapter(db);
      expect(
        (await store.folder())!.read<String>('canonical_root'),
        '/approved/root',
      );
      final bytes = Uint8List.fromList(utf8.encode('source provenance'));
      final c = candidate(bytes, name: 'source.txt');
      final job = await store.reserve(c, 'vault-a');
      expect(job.read<String>('source_root'), '/approved/root');
    },
  );
  test(
    'pure image extraction is bounded and source URI preserves non-UTF8 bytes',
    () {
      final refs = MarkdownImageParser.extractAndResolveImages(
        markdownContent: List.filled(10000, '![x](image.png)').join('\n'),
        filePath: '',
        rootFolderPath: '',
        resolvePaths: false,
        maximumReferences: 101,
      );
      // Unique syntax coalesces. Varying syntax demonstrates the allocation cap.
      expect(refs.length, 1);
      final bounded = MarkdownImageParser.extractAndResolveImages(
        markdownContent: List.generate(
          10000,
          (i) => '![$i](image-$i.png)',
        ).join('\n'),
        filePath: '',
        rootFolderPath: '',
        resolvePaths: false,
        maximumReferences: 101,
      );
      expect(bounded.length, 101);
      expect(
        watchedSourceUri(
          '/approved/folder',
          Uint8List.fromList([0xff, 32, 97, 46, 116, 120, 116]),
        ),
        'file:///approved/folder/%FF%20a.txt',
      );
    },
  );
  test(
    'job transitions reject impossible terminal changes and retries advance generation',
    () async {
      final c = candidate(Uint8List.fromList([1]), name: 'x.txt');
      final job = await store.reserve(c, 'vault-a');
      final id = job.read<String>('id');
      await expectLater(store.transition(id, 'imported'), throwsStateError);
      await store.transition(id, 'failed');
      await expectLater(store.transition(id, 'importing'), throwsStateError);
      await store.retry(id);
      final retried = (await store.rows(
        'SELECT * FROM watched_import_jobs WHERE id=?',
        [id],
      )).single;
      expect(retried.read<int>('generation'), job.read<int>('generation') + 1);
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
