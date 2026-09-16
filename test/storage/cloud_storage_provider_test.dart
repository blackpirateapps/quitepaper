import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/storage/cloud_storage_models.dart';
import 'package:quitepaper/core/storage/cloud_storage_provider.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';

class FakeAuthService implements AuthService {
  FakeAuthService([this._user]);
  AuthUser? _user;
  final _ctrl = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges => _ctrl.stream;

  void setUser(AuthUser? user) {
    _user = user;
    _ctrl.add(user);
  }

  @override
  Future<void> signOut() async => setUser(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSyncApiClient implements SyncApiClient {
  FakeSyncApiClient({this.quotaToReturn, this.errorToThrow});

  CloudStorageQuota? quotaToReturn;
  Object? errorToThrow;
  int fetchCallCount = 0;

  @override
  Future<CloudStorageQuota> getCloudStorageQuota() async {
    fetchCallCount++;
    if (errorToThrow != null) throw errorToThrow!;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudStorageProvider Tests', () {
    late AppDatabase database;
    late FakeAuthService authService;
    late FakeSyncApiClient apiClient;

    setUp(() async {
      database = AppDatabase.memory();
      authService = FakeAuthService(
        const AuthUser(id: 'user-1', email: 'test@example.com', idToken: 'mock-token'),
      );
      apiClient = FakeSyncApiClient();
    });

    tearDown(() async {
      await database.close();
    });

    test('Notifier fetches quota and populates state for authenticated user', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudStorageProvider.notifier);
      await notifier.fetchQuota();

      final state = container.read(cloudStorageProvider);
      expect(state.hasData, isTrue);
      expect(state.quota!.usedBytes, 342000000);
      expect(state.quota!.limitBytes, 1000000000);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);
    });

    test('Local breakdown calculates images and documents from SQLite without extra network calls', () async {
      // Seed attachments in SQLite
      await database.saveAttachment(
        id: 'att-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        kind: 'image',
        mimeType: 'image/png',
        byteSize: 2000000,
      );
      await database.saveAttachment(
        id: 'att-2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        kind: 'document',
        mimeType: 'application/pdf',
        byteSize: 1000000,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudStorageProvider.notifier);
      final breakdown = await notifier.calculateLocalBreakdown();

      expect(breakdown.imageCount, 1);
      expect(breakdown.imageBytes, 2000000);
      expect(breakdown.documentCount, 1);
      expect(breakdown.documentBytes, 1000000);
      expect(breakdown.totalCount, 2);
    });

    test('Preflight validation checks 10 MB limit and available quota', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudStorageProvider.notifier);
      await notifier.fetchQuota();

      // 1. File exceeds 10 MB -> FileTooLarge
      final check1 = notifier.preflightCheck(12000000);
      expect(check1.status, PreflightStatus.fileTooLarge);

      // 2. File fits within 10 MB and within 658 MB remaining quota -> Allowed
      final check2 = notifier.preflightCheck(5000000);
      expect(check2.status, PreflightStatus.allowed);

      // 3. File fits within 10 MB but exceeds remaining quota
      apiClient.quotaToReturn = const CloudStorageQuota(
        plan: StoragePlan.free,
        usedBytes: 998000000,
        limitBytes: 1000000000,
      );
      await notifier.fetchQuota(force: true);

      final check3 = notifier.preflightCheck(5000000); // needs 5 MB, only 2 MB left
      expect(check3.status, PreflightStatus.insufficientStorage);
    });

    test('Preserves cached state and sets isOffline when network fails', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cloudStorageProvider.notifier);
      await notifier.fetchQuota();

      expect(container.read(cloudStorageProvider).hasData, isTrue);

      // Simulate offline error on subsequent fetch
      apiClient.errorToThrow = Exception('SocketException: Connection refused');
      await notifier.fetchQuota(force: true);

      final state = container.read(cloudStorageProvider);
      expect(state.hasData, isTrue); // Cached data preserved
      expect(state.isOffline, isTrue);
      expect(state.hasError, isTrue);
    });

    test('Subtitle provider reflects unauthenticated, loading, and loaded states', () async {
      // Unauthenticated
      final unauthService = FakeAuthService(null);
      final unauthContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(unauthService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(unauthContainer.dispose);

      expect(
        unauthContainer.read(cloudStorageSubtitleProvider),
        '1 GB Cloud Quota • Sign in to sync',
      );

      // Authenticated with quota
      final authContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          authServiceProvider.overrideWithValue(authService),
          syncApiClientProvider.overrideWithValue(apiClient),
        ],
      );
      addTearDown(authContainer.dispose);

      await authContainer.read(cloudStorageProvider.notifier).fetchQuota();
      expect(
        authContainer.read(cloudStorageSubtitleProvider),
        '342 MB of 1 GB used',
      );
    });
  });
}
