import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/maintenance/attachment_maintenance_service.dart';
import 'package:quitepaper/core/maintenance/maintenance_models.dart';
import 'package:quitepaper/core/maintenance/maintenance_provider.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:quitepaper/features/settings/presentation/widgets/maintenance_progress_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncApiClient extends SyncApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSyncEngine implements SyncEngine {
  @override
  SyncState get state => const SyncState();

  @override
  Stream<SyncState> get stateStream => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockKeyManager implements KeyManager {
  MockKeyManager({this.isUnlocked = true});

  @override
  bool isUnlocked;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMaintenanceService extends AttachmentMaintenanceService {
  FakeMaintenanceService({
    required super.database,
    required super.keyManager,
  });

  bool downloadCalled = false;
  bool rerunOcrCalled = false;
  bool rebuildIndexCalled = false;

  @override
  Future<MaintenanceProgress> downloadAllAttachments({
    MaintenanceCancellationToken? cancelToken,
    void Function(MaintenanceProgress progress)? onProgress,
  }) async {
    downloadCalled = true;
    final progress = const MaintenanceProgress(
      taskType: MaintenanceTaskType.downloadAttachments,
      phase: MaintenancePhase.completed,
      totalItems: 3,
      completedItems: 3,
      statusMessage: 'Successfully downloaded 3 attachment(s).',
    );
    onProgress?.call(progress);
    return progress;
  }

  @override
  Future<MaintenanceProgress> rerunOcrForAll({
    MaintenanceCancellationToken? cancelToken,
    void Function(MaintenanceProgress progress)? onProgress,
  }) async {
    rerunOcrCalled = true;
    final progress = const MaintenanceProgress(
      taskType: MaintenanceTaskType.rerunOcr,
      phase: MaintenancePhase.completed,
      totalItems: 2,
      completedItems: 2,
      statusMessage: 'OCR completed for 2 document(s) & image(s).',
    );
    onProgress?.call(progress);
    return progress;
  }

  @override
  Future<void> rebuildSearchIndex() async {
    rebuildIndexCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late MockKeyManager mockKeyManager;
  late FakeMaintenanceService fakeMaintenance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    mockKeyManager = MockKeyManager(isUnlocked: true);
    fakeMaintenance = FakeMaintenanceService(
      database: db,
      keyManager: mockKeyManager,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        syncApiClientProvider.overrideWithValue(MockSyncApiClient()),
        syncEngineProvider.overrideWithValue(FakeSyncEngine()),
        attachmentMaintenanceServiceProvider.overrideWithValue(fakeMaintenance),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: child,
      ),
    );
  }

  testWidgets('SettingsScreen renders Advanced section with all 3 maintenance rows',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    // Scroll to Advanced section
    await tester.scrollUntilVisible(
      find.text('ADVANCED'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify section header
    expect(find.text('ADVANCED'), findsOneWidget);

    // Verify 3 rows
    expect(find.text('Download All Attachments'), findsOneWidget);
    expect(find.text('Download all media and documents from cloud for offline access'), findsOneWidget);

    expect(find.text('Rerun OCR for All Files'), findsOneWidget);
    expect(find.text('Extract text from all local scanned documents and image attachments'), findsOneWidget);

    expect(find.text('Rebuild Search Index'), findsOneWidget);
    expect(find.text('Refresh full-text and OCR indexes for notes and attachments'), findsOneWidget);
  });

  testWidgets('Tapping Download All Attachments opens MaintenanceProgressSheet',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Download All Attachments'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download All Attachments'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceProgressSheet), findsOneWidget);
    expect(find.text('Downloading Attachments'), findsOneWidget);
    expect(find.text('Successfully downloaded 3 attachment(s).'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(fakeMaintenance.downloadCalled, isTrue);

    // Dismiss sheet
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(MaintenanceProgressSheet), findsNothing);
  });

  testWidgets('Tapping Rerun OCR when locked displays Encryption Locked dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockKeyManager.isUnlocked = false;

    await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rerun OCR for All Files'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rerun OCR for All Files'));
    await tester.pumpAndSettle();

    expect(find.text('Encryption Locked'), findsOneWidget);
    expect(find.text('Quiet Paper encryption keys are locked. Please unlock your notebook to extract text and re-run OCR on attachments.'), findsOneWidget);

    // Tap OK
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Encryption Locked'), findsNothing);
    expect(fakeMaintenance.rerunOcrCalled, isFalse);
  });

  testWidgets('Tapping Rerun OCR when unlocked opens MaintenanceProgressSheet',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockKeyManager.isUnlocked = true;

    await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rerun OCR for All Files'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rerun OCR for All Files'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceProgressSheet), findsOneWidget);
    expect(find.text('Running OCR Recognition'), findsOneWidget);
    expect(find.text('OCR completed for 2 document(s) & image(s).'), findsOneWidget);
    expect(fakeMaintenance.rerunOcrCalled, isTrue);
  });

  testWidgets('Tapping Rebuild Search Index prompts confirmation dialog and executes rebuild',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget(child: const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rebuild Search Index'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rebuild Search Index'));
    await tester.pumpAndSettle();

    expect(find.text('Rebuild Search Index'), findsNWidgets(2)); // row title + dialog title
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Rebuild'), findsOneWidget);

    // Confirm rebuild
    await tester.tap(find.text('Rebuild'));
    await tester.pumpAndSettle();

    expect(fakeMaintenance.rebuildIndexCalled, isTrue);
    expect(find.text('Search index rebuilt successfully'), findsOneWidget);
  });
}
