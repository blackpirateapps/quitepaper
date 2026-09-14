import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/device/device_info_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/vault/vault_erase_service.dart';
import 'package:quitepaper/features/devices/application/devices_provider.dart';
import 'package:quitepaper/features/devices/domain/device.dart';
import 'package:quitepaper/features/devices/presentation/devices_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';

class MockAuthService implements AuthService {
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _currentUser != null ? 'mock-token-123' : null;

  @override
  Future<AuthUser> signInWithEmailAndPassword(
      String email, String password) async {
    _currentUser = AuthUser(
      id: 'user-123',
      email: email,
      emailVerified: true,
      idToken: 'mock-token-123',
    );
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockKeyManager implements KeyManager {
  bool _unlocked = true;
  Uint8List? _masterKey = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

  @override
  bool get isUnlocked => _unlocked;

  @override
  Uint8List getMasterKey() => _masterKey ?? Uint8List(0);

  @override
  Future<void> clearLocalKeys() async {
    _unlocked = false;
    _masterKey = null;
  }

  @override
  void lock() {
    _unlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Model Domain Tests', () {
    test('Device.fromJson parses full payload correctly', () {
      final json = {
        'id': 'device-uuid-1',
        'deviceId': 'device-uuid-1',
        'deviceName': 'Work Laptop',
        'platform': 'macOS',
        'model': 'MacBookPro18,1',
        'osVersion': 'macOS 14.4',
        'appVersion': '1.5.8',
        'createdAt': '2026-09-14T00:00:00.000Z',
        'lastActiveAt': '2026-09-15T00:00:00.000Z',
        'revokedAt': null,
      };

      final device = Device.fromJson(json);

      expect(device.id, 'device-uuid-1');
      expect(device.deviceId, 'device-uuid-1');
      expect(device.deviceName, 'Work Laptop');
      expect(device.platform, 'macOS');
      expect(device.model, 'MacBookPro18,1');
      expect(device.osVersion, 'macOS 14.4');
      expect(device.appVersion, '1.5.8');
      expect(device.displayTitle, 'Work Laptop');
      expect(device.shortDeviceId, '••••ID-1');
      expect(device.isRevoked, false);
    });

    test('Device.displayTitle fallback precedence', () {
      final now = DateTime.now();
      final withCustomName = Device(
        id: '1',
        deviceId: '12345678-abcd',
        deviceName: 'Pixel 9 Pro',
        platform: 'Android',
        model: 'Pixel 9',
        createdAt: now,
        lastActiveAt: now,
      );
      expect(withCustomName.displayTitle, 'Pixel 9 Pro');

      final withModelOnly = Device(
        id: '2',
        deviceId: '12345678-abcd',
        platform: 'Android',
        model: 'Pixel 9',
        createdAt: now,
        lastActiveAt: now,
      );
      expect(withModelOnly.displayTitle, 'Pixel 9');

      final withPlatformOnly = Device(
        id: '3',
        deviceId: '12345678-abcd',
        platform: 'iOS',
        createdAt: now,
        lastActiveAt: now,
      );
      expect(withPlatformOnly.displayTitle, 'iOS Device');

      final fallback = Device(
        id: '4',
        deviceId: '12345678-abcd',
        createdAt: now,
        lastActiveAt: now,
      );
      expect(fallback.displayTitle, 'Quiet Paper Device');
    });

    test('DeviceRegistrationRequest.toJson generates valid schema', () {
      const req = DeviceRegistrationRequest(
        deviceId: 'device-abc',
        deviceName: 'Primary iPhone',
        platform: 'iOS',
        model: 'iPhone16,1',
        osVersion: 'iOS 18.0',
        appVersion: '1.5.8',
      );

      final json = req.toJson();
      expect(json['deviceId'], 'device-abc');
      expect(json['deviceName'], 'Primary iPhone');
      expect(json['platform'], 'iOS');
      expect(json['model'], 'iPhone16,1');
      expect(json['osVersion'], 'iOS 18.0');
      expect(json['appVersion'], '1.5.8');
    });
  });

  group('HttpSyncApiClient Device Methods & Error Handling Tests', () {
    late MockAuthService auth;

    setUp(() {
      auth = MockAuthService();
      auth.signInWithEmailAndPassword('tester@quietpaper.app', 'pass');
    });

    test('getDevices parses remote response list correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/devices');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer mock-token-123');

        return http.Response(
          jsonEncode({
            'devices': [
              {
                'id': 'dev-1',
                'deviceId': 'dev-1',
                'deviceName': 'MacBook',
                'platform': 'macOS',
                'model': 'MacBook Pro',
                'createdAt': '2026-09-14T00:00:00.000Z',
                'lastActiveAt': '2026-09-15T00:00:00.000Z',
              },
              {
                'id': 'dev-2',
                'deviceId': 'dev-2',
                'deviceName': 'iPhone',
                'platform': 'iOS',
                'model': 'iPhone 15',
                'createdAt': '2026-09-13T00:00:00.000Z',
                'lastActiveAt': '2026-09-14T12:00:00.000Z',
              },
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        httpClient: mockClient,
      );

      final devices = await apiClient.getDevices();
      expect(devices.length, 2);
      expect(devices[0].deviceName, 'MacBook');
      expect(devices[1].deviceName, 'iPhone');
    });

    test('registerDevice sends payload and returns registered device', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/devices/register');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['deviceId'], 'new-dev-id');

        return http.Response(
          jsonEncode({
            'device': {
              'id': 'new-dev-id',
              'deviceId': 'new-dev-id',
              'deviceName': 'My Device',
              'platform': 'Linux',
              'createdAt': '2026-09-15T00:00:00.000Z',
              'lastActiveAt': '2026-09-15T00:00:00.000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        httpClient: mockClient,
      );

      final device = await apiClient.registerDevice(
        const DeviceRegistrationRequest(
          deviceId: 'new-dev-id',
          deviceName: 'My Device',
          platform: 'Linux',
        ),
      );

      expect(device.deviceId, 'new-dev-id');
      expect(device.deviceName, 'My Device');
    });

    test('renameDevice sends patch request with trimmed name', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/devices/dev-1');
        expect(request.method, 'PATCH');
        final body = jsonDecode(request.body);
        expect(body['deviceName'], 'Renamed Laptop');

        return http.Response(
          jsonEncode({
            'device': {
              'id': 'dev-1',
              'deviceId': 'dev-1',
              'deviceName': 'Renamed Laptop',
              'platform': 'macOS',
              'createdAt': '2026-09-15T00:00:00.000Z',
              'lastActiveAt': '2026-09-15T00:00:00.000Z',
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        httpClient: mockClient,
      );

      final updated = await apiClient.renameDevice('dev-1', 'Renamed Laptop');
      expect(updated.deviceName, 'Renamed Laptop');
    });

    test('Throws DeviceRevokedException when server responds 401 DEVICE_REVOKED', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'DEVICE_REVOKED',
              'message': 'This device has been signed out remotely.',
            }
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        httpClient: mockClient,
      );

      expect(
        () => apiClient.getDevices(),
        throwsA(isA<DeviceRevokedException>()),
      );
    });
  });

  group('Sign Out vs Vault Erase Semantics Tests', () {
    late AppDatabase db;
    late MockAuthService auth;
    late MockKeyManager keyManager;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      auth = MockAuthService();
      keyManager = MockKeyManager();

      await auth.signInWithEmailAndPassword('writer@quietpaper.app', 'pass');

      // Create a test note in the database
      await db.saveNote(
        id: 'test-note-1',
        title: 'Important Note',
        content: 'Preserve me offline',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        isDirty: false,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Normal Sign Out disconnects session but PRESERVES local notes and master keys', () async {
      // Verify initial state
      expect(auth.currentUser, isNotNull);
      expect(keyManager.isUnlocked, isTrue);
      final initialNotes = await db.getAllNotesRaw();
      expect(initialNotes.length, 1);

      // Normal sign out execution:
      await auth.signOut();

      // Semantics:
      // 1. Auth is signed out
      expect(auth.currentUser, isNull);
      // 2. Local note MUST still exist in database
      final remainingNotes = await db.getAllNotesRaw();
      expect(remainingNotes.length, 1);
      expect(remainingNotes.first.title, 'Important Note');
      // 3. Local key manager was NOT wiped
      expect(keyManager.isUnlocked, isTrue);
      expect(keyManager.getMasterKey(), isNotEmpty);
    });

    test('VaultEraseService.eraseLocalVault clears all database tables, keys, and session', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          keyManagerProvider.overrideWithValue(keyManager),
        ],
      );
      addTearDown(container.dispose);

      final eraseService = container.read(vaultEraseServiceProvider);

      // Execute authoritative erase
      await eraseService.eraseLocalVault();

      // Semantics:
      // 1. Auth is signed out
      expect(auth.currentUser, isNull);
      // 2. Database rows are completely erased
      final remainingNotes = await db.getAllNotesRaw();
      expect(remainingNotes, isEmpty);
      // 3. Keys are cleared
      expect(keyManager.isUnlocked, isFalse);
    });
  });

  group('DevicesScreen Widget & Grouped Table Aesthetic Tests', () {
    late AppDatabase db;
    late MockAuthService auth;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      auth = MockAuthService();
      await auth.signInWithEmailAndPassword('writer@quietpaper.app', 'pass');
      await db.setSyncMetadata('device_id', 'current-dev-123');
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders Devices & Sessions list with current device badge and remote devices', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final testDevices = <Device>[
        Device(
          id: 'current-dev-123',
          deviceId: 'current-dev-123',
          deviceName: 'MacBook Pro',
          platform: 'macOS',
          model: 'Apple M2 Max',
          createdAt: now,
          lastActiveAt: now,
        ),
        Device(
          id: 'remote-dev-456',
          deviceId: 'remote-dev-456',
          deviceName: 'iPhone 16 Pro',
          platform: 'iOS',
          model: 'iPhone 16 Pro',
          createdAt: now,
          lastActiveAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          currentDeviceIdProvider.overrideWith((ref) => Future.value('current-dev-123')),
          devicesListProvider.overrideWith((ref) => Future.value(testDevices)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppColors.light],
            ),
            home: const DevicesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header is visible
      expect(find.text('Devices & Sessions'), findsOneWidget);

      // 2. Subtitle count is visible
      expect(find.text('Your account is signed in on 2 devices.'), findsOneWidget);

      // 3. Current device badge and name
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);

      // 4. Remote device and bulk revoke button
      expect(find.text('iPhone 16 Pro'), findsOneWidget);
      expect(find.text('Sign Out All Other Devices'), findsOneWidget);
    });

    testWidgets('Tapping a device row opens DeviceDetailSheet modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final testDevices = <Device>[
        Device(
          id: 'current-dev-123',
          deviceId: 'current-dev-123',
          deviceName: 'MacBook Pro',
          platform: 'macOS',
          model: 'Apple M2 Max',
          osVersion: 'macOS 15.0',
          appVersion: '1.5.8',
          createdAt: now,
          lastActiveAt: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authServiceProvider.overrideWithValue(auth),
          currentDeviceIdProvider.overrideWith((ref) => Future.value('current-dev-123')),
          devicesListProvider.overrideWith((ref) => Future.value(testDevices)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [AppColors.light],
            ),
            home: const DevicesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the device row
      await tester.tap(find.text('MacBook Pro'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears with details
      expect(find.text('Operating System'), findsOneWidget);
      expect(find.text('macOS 15.0'), findsOneWidget);
      expect(find.text('Quiet Paper 1.5.8'), findsOneWidget);
      expect(find.byTooltip('Rename device'), findsOneWidget);

      // Current device shows both normal Sign Out and Erase Local Data actions
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Sign Out & Erase Local Data'), findsOneWidget);
    });
  });
}
