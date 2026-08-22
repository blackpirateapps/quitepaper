import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

class FakeAuthService implements AuthService {
  FakeAuthService({
    required this.initialToken,
    required this.refreshedToken,
  }) {
    _currentUser = AuthUser(
      id: 'user-1',
      email: 'test@user.com',
      idToken: initialToken,
      refreshToken: 'valid-refresh-token',
    );
  }

  final String initialToken;
  final String refreshedToken;
  AuthUser? _currentUser;
  int refreshCallCount = 0;

  @override
  String get apiKey => 'fake-api-key';

  @override
  void setApiKey(String key) {}

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> fetchConfigFromBackend([String? backendUrl]) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async => _currentUser!;

  @override
  Future<AuthUser> signUpWithEmailAndPassword(String email, String password) async => _currentUser!;

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification([String? idToken]) async {}

  @override
  Future<AuthUser?> reloadUser() async => _currentUser;

  @override
  Future<void> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshCallCount++;
      _currentUser = _currentUser?.copyWith(idToken: refreshedToken);
      return refreshedToken;
    }
    return _currentUser?.idToken;
  }
}

void main() {
  group('HttpSyncApiClient 401 Auto-Retry & Resilience Tests', () {
    test('Automatically retries request with refreshed token when server returns 401', () async {
      const expiredToken = 'expired-token-123';
      const freshToken = 'fresh-token-456';
      final auth = FakeAuthService(
        initialToken: expiredToken,
        refreshedToken: freshToken,
      );

      final requestsReceived = <http.BaseRequest>[];
      final client = MockHttpClient((request) async {
        requestsReceived.add(request);
        final authHeader = request.headers['authorization'] ?? '';

        if (authHeader == 'Bearer $expiredToken') {
          // Simulate backend rejecting expired Firebase ID token
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHORIZED',
                'message': 'Invalid or expired Firebase ID token: Firebase ID token has expired. (auth/id-token-expired)',
              }
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        } else if (authHeader == 'Bearer $freshToken') {
          // Server accepts fresh token
          return http.Response(
            jsonEncode({
              'keyVersion': 1,
              'wrappedMasterKey': 'Y2lwaGVy',
              'wrappedNonce': 'bm9uY2U=',
              'kdfAlgorithm': 'argon2id',
              'kdfSalt': 'c2FsdA==',
              'kdfParameters': {
                'memory': 65536,
                'iterations': 3,
                'parallelism': 1,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Unauthorized', 401);
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        baseUrl: 'https://test.quitepaper.com',
        httpClient: client,
      );

      final keys = await apiClient.getKeys();
      expect(keys, isNotNull);
      expect(keys!.keyVersion, 1);
      expect(keys.kdfSalt, 'c2FsdA==');

      // Verify two attempts were made: 1st with expired token, 2nd with fresh token
      expect(requestsReceived.length, 2);
      expect(requestsReceived[0].headers['authorization'], 'Bearer $expiredToken');
      expect(requestsReceived[1].headers['authorization'], 'Bearer $freshToken');
      expect(auth.refreshCallCount, 1);
    });

    test('Sanitizes HTML 404/500/502 responses without leaking HTML tags into exceptions', () async {
      final auth = FakeAuthService(
        initialToken: 'valid-token',
        refreshedToken: 'valid-token',
      );

      final client = MockHttpClient((request) async {
        return http.Response(
          '<!DOCTYPE html><html><head><title>504 Gateway Time-out</title></head><body><center><h1>504 Gateway Time-out</h1></center></body></html>',
          504,
          headers: {'content-type': 'text/html'},
        );
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        baseUrl: 'https://test.quitepaper.com',
        httpClient: client,
      );

      expect(
        () => apiClient.getKeys(),
        throwsA(predicate((e) {
          final msg = e.toString();
          return msg.contains('Sync server is temporarily unavailable (504)') &&
              !msg.contains('<!DOCTYPE html>') &&
              !msg.contains('FormatException');
        })),
      );
    });

    test('Dynamic setBaseUrl updates endpoint URL immediately', () async {
      final auth = FakeAuthService(
        initialToken: 'valid-token',
        refreshedToken: 'valid-token',
      );

      final requestedUris = <Uri>[];
      final client = MockHttpClient((request) async {
        requestedUris.add(request.url);
        return http.Response('{"cursor": 42}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = HttpSyncApiClient(
        authService: auth,
        baseUrl: 'https://initial-server.com',
        httpClient: client,
      );

      await apiClient.getCursor();
      expect(requestedUris.last.host, 'initial-server.com');

      // Update base URL dynamically
      apiClient.setBaseUrl('https://custom-sync-backend.internal:8080///');
      expect(apiClient.baseUrl, 'https://custom-sync-backend.internal:8080');

      await apiClient.getCursor();
      expect(requestedUris.last.host, 'custom-sync-backend.internal');
      expect(requestedUris.last.port, 8080);
    });
  });
}
