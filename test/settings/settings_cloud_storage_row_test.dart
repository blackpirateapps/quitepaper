import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/flavor/app_flavor.dart';
import 'package:quitepaper/core/storage/cloud_storage_models.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/update/update_provider.dart';
import 'package:quitepaper/core/update/update_service.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/cloud_storage_screen.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSyncApiClient extends SyncApiClient {
  MockSyncApiClient({this.quotaToReturn});
  CloudStorageQuota? quotaToReturn;

  @override
  Future<CloudStorageQuota> getCloudStorageQuota() async {
    return quotaToReturn ??
        const CloudStorageQuota(
          plan: StoragePlan.free,
          usedBytes: 342000000,
          limitBytes: 1000000000,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  FakeAuthService([this._user]);
  final AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_user);

  @override
  Future<AuthUser?> reloadUser() async => _user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late MockSyncApiClient mockApi;
  late FakeAuthService mockAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    mockApi = MockSyncApiClient();
    mockAuth = FakeAuthService(
      const AuthUser(id: 'u-1', email: 'writer@example.com', idToken: 'token-1'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSettingsScreen() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(mockAuth),
        syncApiClientProvider.overrideWithValue(mockApi),
        appFlavorProvider.overrideWithValue(AppDistributionFlavor.github),
        updateServiceProvider.overrideWithValue(
          UpdateService(
            sharedPreferences: prefs,
            currentVersion: '1.2.0',
            flavor: AppDistributionFlavor.github,
          ),
        ),
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
        home: const SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen Cloud Storage Row Tests', () {
    testWidgets('Displays Cloud Storage row and navigates to CloudStorageScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSettingsScreen());
      await tester.pumpAndSettle();

      // Scroll until STORAGE & ATTACHMENTS section is visible
      final storageHeader = find.text('STORAGE & ATTACHMENTS');
      await tester.scrollUntilVisible(storageHeader, 300);
      await tester.pumpAndSettle();

      expect(storageHeader, findsOneWidget);

      // Verify Cloud Storage row is visible with Storage & Cleanup row below it
      final cloudStorageRow = find.text('Cloud Storage');
      expect(cloudStorageRow, findsOneWidget);
      expect(find.text('Storage & Cleanup'), findsOneWidget);

      // Tap on Cloud Storage row
      await tester.tap(cloudStorageRow);
      await tester.pumpAndSettle();

      // Verify navigated to CloudStorageScreen
      expect(find.byType(CloudStorageScreen), findsOneWidget);
      expect(find.text('STORAGE BREAKDOWN'), findsOneWidget);
      expect(find.text('PLAN & LIMITS'), findsOneWidget);
    });
  });
}
