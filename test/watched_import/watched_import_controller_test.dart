import 'dart:convert';
import 'package:drift/drift.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/watched_import/application/canonical_import_adapter.dart';
import 'package:quitepaper/features/watched_import/application/native_watched_engine.dart';
import 'package:quitepaper/features/watched_import/application/watched_import_controller.dart';
import 'package:quitepaper/features/watched_import/application/watched_import_provider.dart';
import 'package:quitepaper/features/watched_import/data/watched_import_repository.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';
import 'package:quitepaper/features/watched_import/presentation/watched_folders_screen.dart';
import '../attachments/attachment_service_test.dart' show MockKeyManager;
import 'watched_import_storage_test.dart' show candidate;

class FakeEngine implements WatchedEngine {
  final queued = <EngineEvent>[];
  final snapshots = <String, Uint8List>{};
  final ack = <Outcome>[];
  bool failAck = false;
  void Function()? beforeSnapshot;
  @override
  Future<void> load() async {}
  @override
  Future<RootInfo> inspect(String path, List<String> forbidden) async =>
      RootInfo(canonicalPath: path, identity: '1:2');
  @override
  Future<int> start(
    String id,
    String path,
    String identity,
    bool inventory,
  ) async => 1;
  @override
  Future<void> ready(int handle, bool ready) async {}
  @override
  Future<List<EngineEvent>> events(int handle) async {
    final result = List.of(queued);
    queued.clear();
    return result;
  }

  @override
  Future<Uint8List> snapshot(int handle, String job) async {
    beforeSnapshot?.call();
    return snapshots[job]!;
  }

  @override
  Future<Uint8List> relatedImage(int handle, String job, String target) async =>
      throw StateError('no_fixture');
  @override
  Future<int> acknowledge(int handle, String job, Outcome outcome) async {
    ack.add(outcome);
    if (failAck) {
      failAck = false;
      throw StateError('lost_ack');
    }
    return outcome == Outcome.retry ? 2000 : 0;
  }

  @override
  Future<void> pause(int handle) async {}
  @override
  Future<void> resume(int handle) async {}
  @override
  Future<void> reconcile(int handle) async {}
  @override
  Future<void> stop(int handle) async {}
  void push(Candidate c, Uint8List bytes) {
    snapshots[c.jobId] = bytes;
    queued.add(
      EngineEvent(
        kind: EventKind.stableCandidate,
        candidate: c,
        count: 1,
        generation: 1,
      ),
    );
  }
}

Future<void> until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('condition deadline');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late WatchedImportRepositoryAdapter store;
  late FakeEngine engine;
  late WatchedImportController controller;
  var unlocked = true;
  var scope = 'vault-a';
  setUp(() async {
    unlocked = true;
    scope = 'vault-a';
    db = AppDatabase.memory();
    store = WatchedImportRepositoryAdapter(db);
    engine = FakeEngine();
    final notes = DriftNotesRepository(db);
    final keys = MockKeyManager(masterKey: Uint8List(32));
    final attachments = AttachmentService(database: db, keyManager: keys);
    final email = EmailImportService(
      database: db,
      repository: notes,
      attachments: attachments,
    );
    controller = WatchedImportController(
      store: store,
      engine: engine,
      importer: CanonicalImportAdapter(
        store: store,
        email: email,
        notes: notes,
        attachments: attachments,
        documents: DocumentService(database: db, keyManager: keys),
      ),
      scope: () async => scope,
      isUnlocked: () => unlocked,
      forbiddenPaths: () async => [],
      onImported: () async {},
    );
    await store.enroll(
      const RootInfo(canonicalPath: '/approved/root', identity: '1:2'),
      scope,
    );
    await controller.initialize();
  });
  tearDown(() async {
    await controller.close();
    controller.dispose();
    await db.close();
  });
  Future<void> accept() async {
    final f = (await store.folder())!;
    await store.inventoryDone(f.read<String>('id'), null);
    await store.decide(f.read<String>('id'), true);
    await controller.refresh();
  }

  Candidate make(
    Uint8List bytes, {
    String name = 'a.txt',
    bool initial = true,
  }) {
    final c = candidate(
      bytes,
      name: name,
      folder: controller.configuration!.read<String>('id'),
    );
    return Candidate(
      jobId: c.jobId,
      folderId: c.folderId,
      relativePath: c.relativePath,
      displayName: c.displayName,
      size: c.size,
      revision: c.revision,
      sha256: c.sha256,
      format: c.format,
      generation: c.generation,
      initialInventory: initial,
    );
  }

  test(
    'review creates no note; Only New preserves arrivals after initial inventory',
    () async {
      final old = Uint8List.fromList(utf8.encode('old'));
      final oldC = make(old);
      engine.push(oldC, old);
      await until(() => engine.ack.length == 1);
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      final newer = Uint8List.fromList(utf8.encode('arrived during review'));
      final newC = make(newer, name: 'new.txt', initial: false);
      engine.push(newC, newer);
      await until(() => engine.ack.length == 2);
      final f = (await store.folder())!;
      await store.inventoryDone(f.read<String>('id'), null);
      await controller.decide(false);
      final jobs = await store.rows(
        'SELECT display_name,status FROM watched_import_jobs ORDER BY display_name',
      );
      expect(jobs.first.read<String>('status'), 'baseline_skipped');
      expect(jobs.last.read<String>('status'), 'ready');
      engine.push(make(old, name: 'renamed.txt', initial: false), old);
      engine.push(newC, newer);
      await until(() => engine.ack.length == 4);
      expect((await store.rows('SELECT * FROM notes')).length, 1);
      expect(
        (await store.rows(
          'SELECT content FROM notes',
        )).single.read<String>('content'),
        'arrived during review',
      );
    },
  );
  test(
    'lost ACK redelivery commits at most one note and deleted note stays deleted',
    () async {
      await accept();
      final bytes = Uint8List.fromList(utf8.encode('one note'));
      final c = make(bytes, initial: false);
      engine.failAck = true;
      engine.push(c, bytes);
      await until(() => engine.ack.isNotEmpty);
      engine.push(make(bytes, name: 'copy.txt', initial: false), bytes);
      await until(() => engine.ack.length == 2);
      final notes = await store.rows('SELECT * FROM notes');
      expect(notes.length, 1);
      await DriftNotesRepository(
        db,
      ).deletePermanently(notes.single.read<String>('id'));
      engine.push(
        make(bytes, name: 'renamed-again.txt', initial: false),
        bytes,
      );
      await until(() => engine.ack.length == 3);
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      expect(
        (await store.rows('SELECT * FROM watched_import_receipts')).length,
        1,
      );
    },
  );
  test(
    'lock during snapshot prevents commit and preserves retryable job',
    () async {
      await accept();
      final bytes = Uint8List.fromList(utf8.encode('locked'));
      engine.beforeSnapshot = () {
        unlocked = false;
        controller.accountChanged();
      };
      engine.push(make(bytes, initial: false), bytes);
      await until(() => engine.ack.isNotEmpty);
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      expect(
        await store.rows('SELECT * FROM watched_import_receipts'),
        isEmpty,
      );
      expect(
        (await store.rows(
          'SELECT * FROM watched_import_jobs',
        )).single.read<String>('status'),
        'waiting_for_unlock',
      );
      expect(
        (await store.rows(
          'SELECT next_retry FROM watched_import_jobs',
        )).single.read<int>('next_retry'),
        greaterThan(store.now),
      );
    },
  );
  test(
    'account change stops queued imports and pause does not consume candidates',
    () async {
      await accept();
      await controller.pause();
      final bytes = Uint8List.fromList(utf8.encode('deferred'));
      engine.push(make(bytes, initial: false), bytes);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(engine.ack, isEmpty);
      scope = 'vault-b';
      controller.accountChanged();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(await store.rows('SELECT * FROM notes'), isEmpty);
      expect(controller.error, 'account_changed_select_folder_again');
    },
  );
  for (final dark in [false, true]) {
    testWidgets('review and history fit narrow keyboard viewport, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchedImportControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const WatchedFoldersScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Watched Folders'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Only import new files'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Only import new files'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      // Keep the externally owned test controller alive after scope disposal.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
