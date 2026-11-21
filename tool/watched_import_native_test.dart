import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/watched_import/application/canonical_import_adapter.dart';
import 'package:quitepaper/features/watched_import/application/native_watched_engine.dart';
import 'package:quitepaper/features/watched_import/application/watched_import_controller.dart';
import 'package:quitepaper/features/watched_import/data/watched_import_repository.dart';
import 'package:quitepaper/features/watched_import/native/frb_generated.dart';
import '../test/attachments/attachment_service_test.dart' show MockKeyManager;

class LoadedEngine extends NativeWatchedEngine {
  @override
  Future<void> load() async {}
}

Future<void> until(Future<bool> Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 30));
  while (!await condition()) {
    if (DateTime.now().isAfter(limit)) fail('native acceptance deadline');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Rust observation to canonical EML, receipt, copy dedup and deleted note',
    () async {
      final library = Platform.environment['QP_WATCHED_NATIVE_LIBRARY'];
      if (library == null) {
        throw StateError('Set QP_WATCHED_NATIVE_LIBRARY to the built .so');
      }
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(File(library).absolute.path),
      );
      final root = await Directory.systemTemp.createTemp(
        'qp-native-canonical-',
      );
      final source = Directory('${root.path}/watched');
      await source.create();
      final nested = Directory('${source.path}/nested');
      await nested.create();
      final bytes = await File(
        'test/email_import/fixtures/mixed.eml',
      ).readAsBytes();
      final input = File('${nested.path}/message-fixture.eml');
      await input.writeAsBytes(bytes, flush: true);
      final db = AppDatabase.memory();
      final store = WatchedImportRepositoryAdapter(db);
      final notes = DriftNotesRepository(db);
      final keys = MockKeyManager(
        masterKey: Uint8List.fromList(List.generate(32, (i) => i)),
      );
      final assets = AttachmentService(
        database: db,
        keyManager: keys,
        storage: AttachmentLocalStorage(
          customBaseDirectory: Directory('${root.path}/assets'),
        ),
      );
      final controller = WatchedImportController(
        store: store,
        engine: LoadedEngine(),
        importer: CanonicalImportAdapter(
          store: store,
          email: EmailImportService(
            database: db,
            repository: notes,
            attachments: assets,
          ),
          notes: notes,
          attachments: assets,
          documents: DocumentService(database: db, keyManager: keys),
        ),
        scope: () async => 'native-test-vault',
        isUnlocked: () => true,
        forbiddenPaths: () async => [],
        onImported: () async {},
      );
      try {
        await controller.enroll(source.path);
        expect(controller.error, isNull);
        await until(
          () async =>
              (await store.folder())!.read<int>('inventory_complete') == 1,
        );
        expect(await store.rows('SELECT * FROM notes'), isEmpty);
        await controller.decide(true);
        await until(
          () async =>
              (await store.rows(
                'SELECT * FROM watched_import_receipts',
              )).length ==
              1,
        );
        expect((await store.rows('SELECT * FROM notes')).length, 1);
        final receipt = (await store.rows(
          'SELECT * FROM watched_import_receipts',
        )).single;
        final note = (await notes.getNoteById(
          receipt.read<String>('note_id'),
        ))!;
        expect(note.importSources.single.sender, isNotEmpty);
        expect(note.content, contains('qp://asset/'));
        final original = (await assets.getAttachmentsForNote(
          note.id,
        )).singleWhere((a) => a.mimeType == 'message/rfc822');
        expect(
          (await assets.resolveAsset(original.id)).data,
          orderedEquals(bytes),
        );
        await input.copy('${source.path}/copy.eml');
        await until(
          () async => (await store.rows(
            "SELECT * FROM watched_import_jobs WHERE status='duplicate_skipped'",
          )).isNotEmpty,
        );
        expect((await store.rows('SELECT * FROM notes')).length, 1);
        await notes.deletePermanently(note.id);
        final before = (await store.folder())!.read<int>('last_reconcile');
        await controller.rescan();
        await until(
          () async =>
              (await store.folder())!.read<int>('last_reconcile') > before,
        );
        expect(await store.rows('SELECT * FROM notes'), isEmpty);
        expect(
          (await store.rows('SELECT * FROM watched_import_receipts')).length,
          1,
        );
        expect(await input.readAsBytes(), orderedEquals(bytes));
      } finally {
        await controller.close();
        controller.dispose();
        await db.close();
        await root.delete(recursive: true);
        RustLib.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
