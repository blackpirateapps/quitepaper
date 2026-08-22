import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:quitepaper/features/sync/presentation/change_account_password_dialog.dart';
import 'package:quitepaper/features/sync/presentation/change_encryption_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncApiClient implements SyncApiClient {
  String _baseUrl = 'https://quitepaper.vercel.app';
  @override
  String get baseUrl => _baseUrl;
  @override
  void setBaseUrl(String url) => _baseUrl = url;

  @override
  Future<WrappedMasterKeyData?> getKeys() async => null;

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async =>
      keyData;

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async =>
      const PushSyncResponse(results: [], conflicts: [], cursor: 0);

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  }) async =>
      const PullSyncResponse(changes: [], cursor: 0, hasMore: false);

  @override
  Future<int> getCursor() async => 0;

  @override
  Future<Map<String, dynamic>> getAccount() async =>
      {'email': 'mock@example.com'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSyncEngine implements SyncEngine {
  FakeSyncEngine({SyncState initialState = const SyncState()})
      : _state = initialState;

  SyncState _state;
  final _controller = StreamController<SyncState>.broadcast();

  @override
  SyncState get state => _state;

  @override
  Stream<SyncState> get stateStream => _controller.stream;

  @override
  Future<void> syncNow() async {
    _state = SyncState(
      status: SyncStatus.synced,
      lastSyncedAt: DateTime(2026, 8, 20, 12, 0),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late MockAuthService mockAuth;
  late FakeSyncEngine fakeEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    mockAuth = MockAuthService();
    fakeEngine = FakeSyncEngine();
  });

  tearDown(() async {
    fakeEngine.dispose();
    await db.close();
  });

  Widget createTestWidget({
    required Widget child,
    MockAuthService? auth,
    SyncEngine? engine,
    SyncState? syncState,
  }) {
    final authService = auth ?? mockAuth;
    final syncEngine = engine ?? fakeEngine;
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(authService),
        syncApiClientProvider.overrideWithValue(MockSyncApiClient()),
        syncEngineProvider.overrideWithValue(syncEngine),
        if (syncState != null)
          syncStateProvider.overrideWithValue(syncState),
        backupServiceProvider.overrideWithValue(
          BackupService(
            database: db,
            cryptoService: DefaultCryptoService(),
            sharedPreferences: prefs,
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: child,
      ),
    );
  }

  testWidgets('SettingsScreen renders unauthenticated Cloud Sync card',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('CLOUD SYNC & ENCRYPTION'), findsOneWidget);
    expect(find.text('End-to-End Encrypted Cloud Sync'), findsOneWidget);
    expect(find.text('Set up Encrypted Sync'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
  });

  testWidgets(
      'SettingsScreen renders authenticated Cloud Sync card with all 6 rows in exact order when email is unverified',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockAuth.setMockEmailVerified(false);
    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(
        child: const SettingsScreen(),
        syncState: const SyncState(status: SyncStatus.synced),
      ),
    );
    await tester.pumpAndSettle();

    // 1. User Profile & Sync Status Row
    expect(find.text('writer@quietpaper.app'), findsOneWidget);
    expect(find.text('All notes synced'), findsOneWidget);

    // 2. Conditional Email Verification Row
    expect(find.text('Verify Email Address'), findsOneWidget);
    expect(find.text('Verification required for account recovery.'), findsOneWidget);
    expect(find.text('Resend Link'), findsOneWidget);

    // 3. Sync Now Row
    expect(find.text('Sync Now'), findsOneWidget);

    // 4. Account Password Row
    expect(find.text('Account Password'), findsOneWidget);
    expect(find.text('Login & cloud account credentials'), findsOneWidget);

    // 5. Encryption Password Row
    expect(find.text('Encryption Password'), findsOneWidget);
    expect(find.text('Zero-knowledge note vault key'), findsOneWidget);

    // 6. Sign Out Row
    expect(find.text('Sign Out'), findsOneWidget);

    // Verify vertical ordering: Top-to-bottom Y offsets
    final userProfileOffset = tester.getTopLeft(find.text('writer@quietpaper.app')).dy;
    final verifyEmailOffset = tester.getTopLeft(find.text('Verify Email Address')).dy;
    final syncNowOffset = tester.getTopLeft(find.text('Sync Now')).dy;
    final accountPassOffset = tester.getTopLeft(find.text('Account Password')).dy;
    final encPassOffset = tester.getTopLeft(find.text('Encryption Password')).dy;
    final signOutOffset = tester.getTopLeft(find.text('Sign Out')).dy;

    expect(userProfileOffset < verifyEmailOffset, isTrue);
    expect(verifyEmailOffset < syncNowOffset, isTrue);
    expect(syncNowOffset < accountPassOffset, isTrue);
    expect(accountPassOffset < encPassOffset, isTrue);
    expect(encPassOffset < signOutOffset, isTrue);
  });

  testWidgets(
      'SettingsScreen hides Email Verification row when emailVerified is true',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockAuth.setMockEmailVerified(true);
    await mockAuth.signInWithEmailAndPassword('verified@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('verified@quietpaper.app'), findsOneWidget);
    expect(find.text('Verify Email Address'), findsNothing);
    expect(find.text('Resend Link'), findsNothing);
    expect(find.text('Sync Now'), findsOneWidget);
    expect(find.text('Account Password'), findsOneWidget);
    expect(find.text('Encryption Password'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets(
      'Email verification row triggers resend and starts 60-second cooldown',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    mockAuth.setMockEmailVerified(false);
    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resend Link'), findsOneWidget);

    // Tap "Resend Link"
    await tester.tap(find.text('Resend Link'));
    await tester.pump();

    // Verify SnackBar feedback
    expect(
      find.text('Verification email sent to writer@quietpaper.app'),
      findsOneWidget,
    );

    // Verify cooldown active
    expect(find.text('60s'), findsOneWidget);

    // Advance timer by 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s'), findsOneWidget);
  });

  testWidgets('Sync Now row triggers sync and shows completion feedback',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(
        child: const SettingsScreen(),
        syncState: const SyncState(status: SyncStatus.synced),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync Now'), findsOneWidget);
    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sync complete: All notes up to date'), findsOneWidget);
  });

  testWidgets(
      'Account Password row opens ChangeAccountPasswordDialog with validation and update',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Tap Account Password row
    await tester.tap(find.text('Account Password'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeAccountPasswordDialog), findsOneWidget);
    expect(find.text('1. Verify Current Password'), findsOneWidget);
    expect(find.text('2. Set New Account Password'), findsOneWidget);

    // 1. Submit empty -> validation error
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(
      find.text('Please enter your current account password to verify identity.'),
      findsOneWidget,
    );

    // 2. Enter current password and short new password
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'password123');
    await tester.enterText(textFields.at(1), 'short');
    await tester.enterText(textFields.at(2), 'short');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(
      find.text('New account password must be at least 8 characters long.'),
      findsOneWidget,
    );

    // 3. Enter mismatching passwords
    await tester.enterText(textFields.at(1), 'newPassword123');
    await tester.enterText(textFields.at(2), 'differentPassword123');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text('New passwords do not match.'), findsOneWidget);

    // 4. Enter incorrect current password
    await tester.enterText(textFields.at(0), 'wrongPassword');
    await tester.enterText(textFields.at(1), 'newPassword123');
    await tester.enterText(textFields.at(2), 'newPassword123');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text('Incorrect current password.'), findsOneWidget);

    // 5. Enter correct current password and submit
    await tester.enterText(textFields.at(0), 'password123');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    // Dialog closed and SnackBar shown
    expect(find.byType(ChangeAccountPasswordDialog), findsNothing);
    expect(
      find.text('Account password updated successfully.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Encryption Password row opens ChangeEncryptionPasswordScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Tap Encryption Password row
    await tester.ensureVisible(find.text('Encryption Password'));
    await tester.tap(find.text('Encryption Password'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangeEncryptionPasswordScreen), findsOneWidget);
    expect(find.text('Master Password Rotation'), findsOneWidget);
    expect(find.text('1. Verify Current Vault Ownership'), findsOneWidget);
  });

  testWidgets(
      'Sign Out row shows confirmation dialog and signs out on confirm',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await mockAuth.signInWithEmailAndPassword('writer@quietpaper.app', 'password123');

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('writer@quietpaper.app'), findsOneWidget);

    // Ensure Sign Out row is visible
    await tester.ensureVisible(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // Tap Sign Out row
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(
      find.text(
          'Sign out of writer@quietpaper.app? Local notes will remain on this device.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // User is still logged in
    expect(find.text('writer@quietpaper.app'), findsOneWidget);

    // Tap Sign Out again and confirm
    await tester.ensureVisible(find.text('Sign Out'));
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();

    // Scroll back to top to verify unauthenticated card is shown
    await tester.scrollUntilVisible(
      find.text('Set up Encrypted Sync'),
      -200.0,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Set up Encrypted Sync'), findsOneWidget);
    expect(find.text('End-to-End Encrypted Cloud Sync'), findsOneWidget);
  });

  testWidgets(
      'SettingsScreen renders centered grouped list on tablet layout',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 680),
    );
    expect(constrainedBox.constraints.maxWidth, 680);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('CLOUD SYNC & ENCRYPTION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
