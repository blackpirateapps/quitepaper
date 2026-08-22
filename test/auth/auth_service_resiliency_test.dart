import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quitepaper/core/auth/auth_service.dart';

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

void main() {
  group('AuthUser Token Expiry Tests', () {
    test('isTokenExpired returns false when token has plenty of time remaining', () {
      final user = AuthUser(
        id: 'u1',
        email: 'test@example.com',
        idToken: 'valid-token',
        tokenExpiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(user.isTokenExpired, false);
    });

    test('isTokenExpired returns true when token is within 5 minutes of expiration (proactive margin)', () {
      final user = AuthUser(
        id: 'u1',
        email: 'test@example.com',
        idToken: 'near-expiry-token',
        tokenExpiresAt: DateTime.now().add(const Duration(minutes: 4)),
      );
      expect(user.isTokenExpired, true);
    });

    test('isTokenExpired returns true when token is in the past', () {
      final user = AuthUser(
        id: 'u1',
        email: 'test@example.com',
        idToken: 'expired-token',
        tokenExpiresAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(user.isTokenExpired, true);
    });

    test('isTokenExpired returns false when tokenExpiresAt is null', () {
      const user = AuthUser(
        id: 'u1',
        email: 'test@example.com',
        idToken: 'token',
      );
      expect(user.isTokenExpired, false);
    });
  });

  group('FirebaseAuthService Resiliency & Safe JSON Parsing Tests', () {
    late Map<String, String> mockSecureStore;

    setUp(() {
      mockSecureStore = {};
      FlutterSecureStorage.setMockInitialValues(mockSecureStore);
    });

    test('signInWithEmailAndPassword handles HTML 404/500/502 without FormatException', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          '<!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body><h1>Bad Gateway</h1></body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signInWithEmailAndPassword('user@test.com', 'password123'),
        throwsA(predicate((e) {
          final str = e.toString();
          return str.contains('Authentication service is temporarily unavailable (HTTP 502)') &&
              !str.contains('FormatException') &&
              !str.contains('<!DOCTYPE');
        })),
      );
    });

    test('signInWithEmailAndPassword maps Firebase error codes cleanly', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 400,
              'message': 'INVALID_LOGIN_CREDENTIALS',
              'errors': [{'message': 'INVALID_LOGIN_CREDENTIALS', 'domain': 'global', 'reason': 'invalid'}],
            }
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signInWithEmailAndPassword('user@test.com', 'wrongpassword'),
        throwsA(predicate((e) => e.toString().contains('Incorrect account login password.'))),
      );
    });

    test('signInWithEmailAndPassword maps 403 OPERATION_NOT_ALLOWED to actionable message', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'OPERATION_NOT_ALLOWED',
            }
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signInWithEmailAndPassword('user@test.com', 'password123'),
        throwsA(predicate((e) =>
            e.toString().contains('Email/Password sign-in is disabled in your Firebase project'))),
      );
    });

    test('signInWithEmailAndPassword maps generic 403 to clear troubleshooting guidance', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          'Forbidden',
          403,
          headers: {'content-type': 'text/plain'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signInWithEmailAndPassword('user@test.com', 'password123'),
        throwsA(predicate((e) =>
            e.toString().contains('Access forbidden (HTTP 403). Please verify that Email/Password authentication'))),
      );
    });

    test('signUpWithEmailAndPassword handles HTML error pages without FormatException', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          '<html><body><h1>Server Error</h1></body></html>',
          500,
          headers: {'content-type': 'text/html'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signUpWithEmailAndPassword('user@test.com', 'password123'),
        throwsA(predicate((e) {
          final str = e.toString();
          return str.contains('Authentication service is temporarily unavailable (HTTP 500)') &&
              !str.contains('FormatException') &&
              !str.contains('<html>');
        })),
      );
    });

    test('signUpWithEmailAndPassword maps EMAIL_EXISTS error cleanly', () async {
      final client = MockHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 400,
              'message': 'EMAIL_EXISTS',
            }
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      expect(
        () => auth.signUpWithEmailAndPassword('existing@test.com', 'password123'),
        throwsA(predicate((e) => e.toString().contains('This email is already registered. Please sign in.'))),
      );
    });

    test('getIdToken forceRefresh contacts SecureToken API and updates session', () async {
      final client = MockHttpClient((request) async {
        if (request.url.host == 'securetoken.googleapis.com') {
          return http.Response(
            jsonEncode({
              'access_token': 'new-access-token',
              'expires_in': '3600',
              'token_type': 'Bearer',
              'refresh_token': 'new-refresh-token-xyz',
              'id_token': 'refreshed-jwt-id-token-456',
              'user_id': 'firebase-user-123',
              'project_id': 'quietpaper',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final auth = FirebaseAuthService(
        apiKey: 'test-api-key',
        httpClient: client,
      );

      // Pre-seed user with expiring token
      const initialUser = AuthUser(
        id: 'firebase-user-123',
        email: 'user@test.com',
        idToken: 'stale-id-token-123',
        refreshToken: 'refresh-token-abc',
      );
      await const FlutterSecureStorage().write(
        key: 'quietpaper_auth_session_v1',
        value: jsonEncode(initialUser.toJson()),
      );

      await auth.initialize();
      expect(auth.currentUser?.idToken, 'stale-id-token-123');

      // Request force refresh
      final refreshedToken = await auth.getIdToken(forceRefresh: true);
      expect(refreshedToken, 'refreshed-jwt-id-token-456');
      expect(auth.currentUser?.idToken, 'refreshed-jwt-id-token-456');
      expect(auth.currentUser?.refreshToken, 'new-refresh-token-xyz');
    });
  });
}
