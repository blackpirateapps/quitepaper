import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/sidebar/presentation/sidebar_view.dart';
import 'package:quitepaper/features/sidebar/presentation/widgets/sidebar_sync_tile.dart';
import 'package:quitepaper/features/sync/presentation/conflict_list_screen.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSyncEngine implements SyncEngine {
  FakeSyncEngine({SyncState initialState = const SyncState()})
      : _state = initialState;

  SyncState _state;
  final _controller = StreamController<SyncState>.broadcast();
  int syncNowCallCount = 0;

  @override
  SyncState get state => _state;

  @override
  Stream<SyncState> get stateStream => _controller.stream;

  @override
  Future<void> syncNow() async {
    syncNowCallCount++;
    _state = _state.copyWith(
      status: SyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
    _controller.add(_state);
  }

  @override
  void dispose() {
    _controller.close();
  }

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSyncEngine fakeEngine;
  late MockKeyManager mockKeyManager;

  setUp(() {
    fakeEngine = FakeSyncEngine();
    mockKeyManager = MockKeyManager(isUnlocked: true);
  });

  Widget createTestWidget({
    Widget? child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        syncEngineProvider.overrideWithValue(fakeEngine),
        keyManagerProvider.overrideWithValue(mockKeyManager),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: Scaffold(
          body: child ?? const SidebarSyncTile(),
        ),
      ),
    );
  }

  testWidgets('displays Local Vault and opens offline dialog when logged out',
      (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          syncStateProvider.overrideWithValue(
            const SyncState(status: SyncStatus.localOnly),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(0)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Vault'), findsOneWidget);
    expect(find.text('Tap to set up sync'), findsOneWidget);

    // Tap tile to open offline storage dialog
    await tester.tap(find.text('Local Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Storage'), findsOneWidget);
    expect(
      find.textContaining('Quiet Paper keeps your notes private'),
      findsOneWidget,
    );
    expect(find.text('Set up Encrypted Sync'), findsOneWidget);

    // Tap "Set up Encrypted Sync" button
    await tester.tap(find.text('Set up Encrypted Sync'));
    await tester.pumpAndSettle();

    expect(find.byType(SyncAuthScreen), findsOneWidget);
  });

  testWidgets('displays email and triggers syncNow when signed in',
      (tester) async {
    const user = AuthUser(
      id: 'uid-123',
      email: 'user@example.com',
      idToken: 'mock-token',
    );

    final lastSync = DateTime.now();

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          syncStateProvider.overrideWithValue(
            SyncState(
              status: SyncStatus.synced,
              lastSyncedAt: lastSync,
            ),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(0)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Just now'), findsOneWidget);

    // Tap to sync
    await tester.tap(find.text('Sync'));
    await tester.pump();

    expect(fakeEngine.syncNowCallCount, 1);
  });

  testWidgets('displays syncing state label when sync is in progress',
      (tester) async {
    const user = AuthUser(
      id: 'uid-123',
      email: 'user@example.com',
      idToken: 'mock-token',
    );

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          syncStateProvider.overrideWithValue(
            const SyncState(status: SyncStatus.syncing),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(0)),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Syncing...'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.text('Updating changes...'), findsOneWidget);
  });

  testWidgets('displays conflict banner and navigates to ConflictListScreen',
      (tester) async {
    const user = AuthUser(
      id: 'uid-123',
      email: 'user@example.com',
      idToken: 'mock-token',
    );

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          syncStateProvider.overrideWithValue(
            const SyncState(
              status: SyncStatus.synced,
              conflictsCount: 3,
            ),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(3)),
          pendingConflictsStreamProvider
              .overrideWith((ref) => Stream.value([])),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 conflicts require review'), findsOneWidget);

    // Tap conflict banner
    await tester.tap(find.text('3 conflicts require review'));
    await tester.pumpAndSettle();

    expect(find.byType(ConflictListScreen), findsOneWidget);
  });

  testWidgets('displays encryption locked state when key manager is locked',
      (tester) async {
    const user = AuthUser(
      id: 'uid-123',
      email: 'user@example.com',
      idToken: 'mock-token',
    );
    mockKeyManager.isUnlocked = false;

    await tester.pumpWidget(
      createTestWidget(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          syncStateProvider.overrideWithValue(
            const SyncState(status: SyncStatus.pendingSync),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(0)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Encryption Locked'), findsOneWidget);
    expect(find.text('Unlock to sync'), findsOneWidget);

    // Tap tile
    await tester.tap(find.text('Encryption Locked'));
    await tester.pump();

    expect(
      find.textContaining('Encryption locked. Please enter your encryption password'),
      findsOneWidget,
    );
  });

  testWidgets('SidebarView contains SidebarSyncTile and no Clip Webpage option',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.memory();
    final repository = DriftNotesRepository(db);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          activeNotesCountProvider.overrideWith((ref) => Stream.value(0)),
          pinnedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
          archivedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
          trashedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
          allTagsStreamProvider.overrideWith((ref) => Stream.value([])),
          hasTodayJournalEntryProvider.overrideWithValue(false),
          syncEngineProvider.overrideWithValue(fakeEngine),
          keyManagerProvider.overrideWithValue(mockKeyManager),
          currentUserProvider.overrideWithValue(null),
          syncStateProvider.overrideWithValue(
            const SyncState(status: SyncStatus.localOnly),
          ),
          pendingConflictsCountStreamProvider
              .overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: const Scaffold(
            body: SidebarView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Clip Webpage is gone
    expect(find.text('Clip Webpage'), findsNothing);

    // Verify Settings is present
    expect(find.text('Settings'), findsOneWidget);

    // Verify SidebarSyncTile is present
    expect(find.byType(SidebarSyncTile), findsOneWidget);
    expect(find.text('Local Vault'), findsOneWidget);

    await db.close();
  });
}
