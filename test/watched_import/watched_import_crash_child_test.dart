import 'dart:io';
import 'package:drift/drift.dart' show Uint8List;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/watched_import/application/canonical_import_adapter.dart';
import 'package:quitepaper/features/watched_import/data/watched_import_repository.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';
import '../attachments/attachment_service_test.dart' show MockKeyManager;
import 'watched_import_storage_test.dart' show candidate;

class CrashAssets extends AttachmentService {
  CrashAssets({
    required super.database,
    required super.keyManager,
    required super.storage,
    required this.crash,
  });
  final bool crash;
  @override
  Future<({AttachmentEntity attachment, String markdownSnippet})>
  importEmailAsset(
    Uint8List bytes, {
    required String assetId,
    required String fileName,
    required String mimeType,
    required String noteId,
    bool original = false,
    bool inlineImage = false,
  }) async {
    final result = await super.importEmailAsset(
      bytes,
      assetId: assetId,
      fileName: fileName,
      mimeType: mimeType,
      noteId: noteId,
      original: original,
      inlineImage: inlineImage,
    );
    if (crash) exit(71);
    return result;
  }
}

class CrashStore extends WatchedImportRepositoryAdapter {
  CrashStore(super.database, this.crash);
  final bool crash;
  @override
  Future<void> commitReceipt(
    dynamic job,
    Candidate c, {
    String? messageId,
  }) async {
    await super.commitReceipt(job, c, messageId: messageId);
    if (crash) {
      exit(72); // SQL transaction is still open, including its receipt.
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('watched crash child', () async {
    final root = Platform.environment['QP_WATCHED_CRASH_ROOT'];
    if (root == null) {
      return; // Subprocess entry, invoked by the crash acceptance test.
    }
    expect(p.isWithin(Directory.systemTemp.path, root), isTrue);
    expect(p.basename(root), startsWith('qp-watched-crash-'));
    final phase = Platform.environment['QP_WATCHED_CRASH_PHASE'];
    final db = AppDatabase(NativeDatabase(File('$root/db.sqlite')));
    final store = CrashStore(db, phase == 'before_commit');
    final notes = DriftNotesRepository(db);
    final keys = MockKeyManager(
      masterKey: Uint8List.fromList(List.generate(32, (i) => i)),
    );
    final assets = CrashAssets(
      database: db,
      keyManager: keys,
      storage: AttachmentLocalStorage(
        customBaseDirectory: Directory('$root/assets'),
      ),
      crash: phase == 'mid_stage',
    );
    final email = EmailImportService(
      database: db,
      repository: notes,
      attachments: assets,
    );
    final adapter = CanonicalImportAdapter(
      store: store,
      email: email,
      notes: notes,
      attachments: assets,
      documents: DocumentService(database: db, keyManager: keys),
    );
    if (await store.folder() == null) {
      await store.enroll(
        const RootInfo(canonicalPath: '/synthetic', identity: '1:2'),
        'crash-vault',
      );
    }
    final source = File('$root/source.eml');
    final bytes = await source.readAsBytes();
    final c = candidate(bytes);
    await adapter.recover();
    final prior = await store.receipt('crash-vault', c);
    if (prior == null) {
      final job = await store.reserve(c, 'crash-vault');
      await adapter.import(c, job, bytes, isCurrent: () => true);
    }
    if (phase == 'after_commit') exit(73); // Lost native acknowledgement.
    expect((await store.rows('SELECT * FROM notes')).length, 1);
    expect(
      (await store.rows('SELECT * FROM watched_import_receipts')).length,
      1,
    );
    expect(
      await store.rows('SELECT * FROM email_import_preparations'),
      isEmpty,
    );
    expect(await store.rows('SELECT * FROM watched_import_stages'), isEmpty);
    final all = await store.rows('SELECT * FROM attachments');
    final files = await Directory(
      '$root/assets',
    ).list(recursive: true).where((f) => f is File).toList();
    expect(files.length, all.length);
    expect(await source.readAsBytes(), orderedEquals(bytes));
    stdout.writeln('QP_WATCHED_CRASH_RECOVERY_OK');
    await db.close();
  });
}
