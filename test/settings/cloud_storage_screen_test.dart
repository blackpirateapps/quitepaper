import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/storage/cloud_storage_models.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/presentation/cloud_storage_screen.dart';

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
          breakdown: StorageBreakdown(
            imageBytes: 284000000,
            imageCount: 23,
            documentBytes: 42000000,
            documentCount: 4,
            otherBytes: 16000000,
            otherCount: 7,
          ),
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
  late MockSyncApiClient mockApi;
  late FakeAuthService mockAuth;

  setUp(() {
    db = AppDatabase.memory();
    mockApi = MockSyncApiClient();
    mockAuth = FakeAuthService(
      const AuthUser(id: 'u-1', email: 'writer@example.com', idToken: 'token-1'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(mockAuth),
        syncApiClientProvider.overrideWithValue(mockApi),
        ...overrides,
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: const CloudStorageScreen(),
      ),
    );
  }

  group('CloudStorageScreen Widget Tests', () {
    testWidgets('Renders loaded Free plan storage quota, breakdown, and limits',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Cloud Storage'), findsWidgets);

      // Main usage card
      expect(find.text('342 MB of 1 GB used', findRichText: true), findsOneWidget);
      expect(find.text('658 MB remaining'), findsOneWidget);
      expect(find.text('34.2%'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);

      // Storage breakdown
      expect(find.text('STORAGE BREAKDOWN'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('284 MB'), findsOneWidget);
      expect(find.text('Documents & PDFs'), findsOneWidget);
      expect(find.text('42 MB'), findsOneWidget);
      expect(find.text('Other files'), findsOneWidget);
      expect(find.text('16 MB'), findsOneWidget);
      expect(find.text('Total Used'), findsOneWidget);

      // Plan & limits
      expect(find.text('PLAN & LIMITS'), findsOneWidget);
      expect(find.text('Cloud Storage Limit'), findsOneWidget);
      expect(find.text('1 GB'), findsWidgets);
      expect(find.text('Max Individual File Size'), findsOneWidget);
      expect(find.text('10 MB'), findsOneWidget);
      expect(find.text('Zero-Knowledge Encryption'), findsOneWidget);
      expect(find.text('AES-256-GCM'), findsOneWidget);

      // Free plan upgrade prompt
      final learnMoreBtn = find.text('Learn More');
      await tester.scrollUntilVisible(learnMoreBtn, 150);
      await tester.pumpAndSettle();
      expect(find.text('Need more room?'), findsOneWidget);
      expect(learnMoreBtn, findsOneWidget);

      // Manage storage entry points
      final manageStorageHeader = find.text('MANAGE STORAGE');
      await tester.scrollUntilVisible(manageStorageHeader, 150);
      await tester.pumpAndSettle();
      expect(manageStorageHeader, findsOneWidget);
      expect(find.text('Storage & Cleanup'), findsOneWidget);
      expect(find.text('Attached Assets'), findsOneWidget);
      expect(find.text('Orphaned Assets'), findsOneWidget);
    });

    testWidgets('Tapping Learn More shows dialog with Premium plan details',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final learnMoreBtn = find.text('Learn More');
      await tester.scrollUntilVisible(learnMoreBtn, 150);
      await tester.pumpAndSettle();

      await tester.tap(learnMoreBtn);
      await tester.pumpAndSettle();

      expect(find.text('Quiet Paper Premium'), findsOneWidget);
      expect(find.text('10 GB Zero-Knowledge Encrypted Cloud Storage'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Quiet Paper Premium'), findsNothing);
    });

    testWidgets('Renders Over-Quota state correctly after downgrade',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockApi.quotaToReturn = const CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 9200000000,
        limitBytes: 1000000000,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('9.2 GB'), findsWidgets);
      expect(find.text('of 1 GB limit (8.2 GB over limit)'), findsOneWidget);
      expect(find.text('Uploads paused until space is freed'), findsOneWidget);
    });

    testWidgets('Renders Premium active plan without upgrade card',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      mockApi.quotaToReturn = const CloudStorageQuota(
        plan: StoragePlan.premium,
        usedBytes: 2400000000,
        limitBytes: 10000000000,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('2.4 GB of 10 GB used', findRichText: true), findsOneWidget);
      expect(find.text('7.6 GB remaining'), findsOneWidget);
      expect(find.text('Need more room?'), findsNothing);
    });
  });
}
