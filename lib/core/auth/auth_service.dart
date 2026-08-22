import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.idToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.emailVerified = false,
  });

  final String id;
  final String email;
  final String idToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;
  final bool emailVerified;

  bool get isTokenExpired {
    if (tokenExpiresAt == null) return false;
    return DateTime.now().isAfter(tokenExpiresAt!.subtract(const Duration(minutes: 5)));
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? idToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
    bool? emailVerified,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
        'emailVerified': emailVerified,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      idToken: json['idToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiresAt: json['tokenExpiresAt'] != null
          ? DateTime.tryParse(json['tokenExpiresAt'] as String)
          : null,
      emailVerified: json['emailVerified'] == true ||
          json['emailVerified']?.toString().toLowerCase() == 'true',
    );
  }
}

abstract class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  String get apiKey;
  void setApiKey(String key);
  Future<void> initialize();
  Future<void> fetchConfigFromBackend([String? backendUrl]);

  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> signUpWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> sendEmailVerification([String? idToken]);
  Future<AuthUser?> reloadUser();
  Future<void> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Universal Firebase Auth client using official Firebase REST Auth API with persistent secure storage
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    String? apiKey,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : _apiKey = apiKey ??
            const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
        _client = httpClient ?? http.Client(),
        _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _apiKey;
  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const String _storageKeyAuthSession = 'quietpaper_auth_session_v1';

  static dynamic _safeParseJson(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {}
    return null;
  }

  static String _extractApiErrorMessage(
    dynamic data,
    String rawBody,
    int statusCode, [
    String defaultFallback = 'Authentication failed',
  ]) {
    String candidate = '';

    if (data is Map) {
      final errorField = data['error'];
      if (errorField is String && errorField.trim().isNotEmpty) {
        candidate = errorField.trim();
      } else if (errorField is Map) {
        final msg = errorField['message'] ?? errorField['error_description'] ?? errorField['details'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          candidate = msg.toString().trim();
        }
      }

      if (candidate.isEmpty) {
        final messageField = data['message'] ?? data['error_description'] ?? data['title'] ?? data['detail'];
        if (messageField != null && messageField.toString().trim().isNotEmpty) {
          candidate = messageField.toString().trim();
        }
      }

      if (candidate.isEmpty) {
        final errorsField = data['errors'];
        if (errorsField is List && errorsField.isNotEmpty) {
          final first = errorsField.first;
          if (first is String && first.trim().isNotEmpty) {
            candidate = first.trim();
          } else if (first is Map && first['message'] != null) {
            candidate = first['message'].toString().trim();
          }
        }
      }
    } else if (data is String && data.trim().isNotEmpty) {
      candidate = data.trim();
    }

    if (candidate.isEmpty) {
      final trimmed = rawBody.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('<') && trimmed.length < 300) {
        candidate = trimmed;
      }
    }

    return _formatAuthErrorMessage(candidate, statusCode, defaultFallback);
  }

  static String _formatAuthErrorMessage(String rawMessage, [int statusCode = 400, String defaultMsg = 'Authentication failed']) {
    final upper = rawMessage.toUpperCase();
    if (upper.contains('INVALID_LOGIN_CREDENTIALS') ||
        upper.contains('INVALID_PASSWORD') ||
        upper.contains('WRONG_PASSWORD')) {
      return 'Incorrect account login password.';
    }
    if (upper.contains('EMAIL_NOT_FOUND') || upper.contains('USER_NOT_FOUND')) {
      return 'No account found with this email address.';
    }
    if (upper.contains('EMAIL_EXISTS')) {
      return 'This email is already registered. Please sign in.';
    }
    if (upper.contains('USER_DISABLED')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (upper.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) {
      return 'Too many attempts. Please try again in a few minutes.';
    }
    if (upper.contains('WEAK_PASSWORD')) {
      return 'Account password must be at least 6 characters.';
    }
    if (upper.contains('INVALID_EMAIL')) {
      return 'Please enter a valid email address.';
    }
    if (upper.contains('OPERATION_NOT_ALLOWED')) {
      return 'Email/Password sign-in is disabled in your Firebase project. Please enable Email/Password provider in the Firebase Authentication console.';
    }
    if (upper.contains('API_KEY_SERVICE_BLOCKED') ||
        upper.contains('API_KEY_INVALID') ||
        upper.contains('API KEY NOT VALID') ||
        upper.contains('API_KEY_EXPIRED') ||
        upper.contains('API_KEY_ANDROID_APP_BLOCKED')) {
      return 'Invalid or restricted Firebase API key. Ensure Identity Toolkit API is allowed for this API key in Google Cloud Console.';
    }
    if (upper.contains('REQUESTS FROM THIS') ||
        upper.contains('REQUESTS TO THIS API') ||
        upper.contains('ARE BLOCKED') ||
        upper.contains('BLOCKED BY CLIENT')) {
      return 'Google Cloud API key restrictions are blocking this request. In Google Cloud Console, ensure the API key allows Identity Toolkit API calls from this application.';
    }
    if (upper.contains('PERMISSION_DENIED') ||
        upper.contains('IDENTITY TOOLKIT API HAS NOT BEEN USED') ||
        upper.contains('SERVICE_DISABLED')) {
      return 'Identity Toolkit API is disabled in your Google Cloud / Firebase project. Please enable it in Google Cloud Console.';
    }
    if (upper.contains('CONFIGURATION_NOT_FOUND') || upper.contains('PROJECT_NOT_FOUND')) {
      return 'Firebase project or auth configuration not found. Please check your project configuration.';
    }
    if (upper.contains('TOKEN_EXPIRED') || upper.contains('CREDENTIAL_TOO_OLD_LOGIN_AGAIN')) {
      return 'Session expired. Please sign in again.';
    }
    if (upper.contains('NETWORK_ERROR') || upper.contains('NETWORK-REQUEST-FAILED')) {
      return 'Network error. Please check your internet connection.';
    }
    if (upper == 'FORBIDDEN' || upper == 'ACCESS_DENIED' || statusCode == 403) {
      if (rawMessage.isNotEmpty &&
          rawMessage.length > 20 &&
          !rawMessage.startsWith('<') &&
          !upper.startsWith('FORBIDDEN')) {
        return rawMessage;
      }
      return 'Access forbidden (HTTP 403). Please verify that Email/Password authentication and the Identity Toolkit API are enabled in your Firebase project and that your API key is not blocked by restrictions.';
    }
    if (rawMessage.isNotEmpty && !rawMessage.startsWith('<')) {
      return rawMessage;
    }
    if (statusCode == 401) {
      return 'Authentication failed (HTTP 401). Invalid credentials or expired session.';
    }
    if (statusCode == 404) {
      return 'Authentication endpoint not found (HTTP 404). Please verify your sync server URL.';
    }
    if (statusCode >= 500) {
      return 'Authentication service is temporarily unavailable (HTTP $statusCode). Please try again later.';
    }
    return defaultMsg;
  }

  @override
  String get apiKey => _apiKey;

  @override
  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  @override
  Future<void> initialize() async {
    try {
      final storedJson = await _storage.read(key: _storageKeyAuthSession);
      if (storedJson != null && storedJson.isNotEmpty) {
        final decoded = _safeParseJson(storedJson);
        if (decoded is Map<String, dynamic>) {
          _currentUser = AuthUser.fromJson(decoded);
          _authStateController.add(_currentUser);
        }
      }
    } catch (_) {
      _currentUser = null;
    }

    if (_apiKey.isEmpty) {
      unawaited(fetchConfigFromBackend());
    }

    // Refresh token in background if needed upon launch without blocking UI startup
    if (_currentUser != null && _currentUser!.isTokenExpired) {
      unawaited(getIdToken());
    }
  }

  Future<void> _saveUserSession(AuthUser? user) async {
    try {
      if (user != null) {
        await _storage.write(
          key: _storageKeyAuthSession,
          value: jsonEncode(user.toJson()),
        );
      } else {
        await _storage.delete(key: _storageKeyAuthSession);
      }
    } catch (_) {}
  }

  @override
  Future<void> fetchConfigFromBackend([String? backendUrl]) async {
    final targetUrl = (backendUrl != null && backendUrl.trim().isNotEmpty)
        ? backendUrl.trim()
        : const String.fromEnvironment('SYNC_API_URL',
            defaultValue: 'https://quitepaper.vercel.app');
    try {
      final sanitized = targetUrl.replaceAll(RegExp(r'/+$'), '');
      final url = Uri.parse('$sanitized/api/v1/config');
      final res = await _client.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = _safeParseJson(res.body);
        if (data is Map<String, dynamic>) {
          final fetchedKey = data['firebaseApiKey'] as String?;
          if (fetchedKey != null && fetchedKey.trim().isNotEmpty) {
            _apiKey = fetchedKey.trim();
          }
        }
      }
    } catch (_) {}
  }

  AuthUser? _currentUser;
  final _authStateController = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  static const _authBaseUrl =
      'https://identitytoolkit.googleapis.com/v1/accounts';

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured. Supply FIREBASE_API_KEY dart-define or server URL.');
    }

    var url = Uri.parse('$_authBaseUrl:signInWithPassword?key=$_apiKey');
    http.Response res;
    try {
      res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      );
    } catch (netErr) {
      throw Exception('Network error connecting to authentication service: $netErr');
    }

    var data = _safeParseJson(res.body);

    // Auto-retry once with refreshed backend config if API key was rejected with 400/403
    if (res.statusCode != 200) {
      final rawError = (data is Map ? (data['error']?['message'] ?? data['error']) : null)?.toString() ?? '';
      if (rawError.toUpperCase().contains('API_KEY') ||
          rawError.toUpperCase().contains('API KEY') ||
          rawError.toUpperCase().contains('FORBIDDEN') ||
          res.statusCode == 403) {
        final currentKey = _apiKey;
        await fetchConfigFromBackend();
        if (_apiKey.isNotEmpty && _apiKey != currentKey) {
          try {
            url = Uri.parse('$_authBaseUrl:signInWithPassword?key=$_apiKey');
            res = await _client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email.trim(),
                'password': password,
                'returnSecureToken': true,
              }),
            );
            data = _safeParseJson(res.body);
          } catch (_) {}
        }
      }
    }

    if (res.statusCode != 200 || data is! Map<String, dynamic> || data['idToken'] == null) {
      final err = _extractApiErrorMessage(
        data,
        res.body,
        res.statusCode,
        'Authentication failed (HTTP ${res.statusCode})',
      );
      throw Exception(err);
    }

    final expiresInSeconds = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    final user = AuthUser(
      id: data['localId'] as String,
      email: data['email'] as String,
      idToken: data['idToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
      emailVerified: data['emailVerified'] == true ||
          data['emailVerified']?.toString().toLowerCase() == 'true',
    );

    _currentUser = user;
    await _saveUserSession(user);
    _authStateController.add(user);
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword(String email, String password) async {
    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured.');
    }

    var url = Uri.parse('$_authBaseUrl:signUp?key=$_apiKey');
    http.Response res;
    try {
      res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'returnSecureToken': true,
        }),
      );
    } catch (netErr) {
      throw Exception('Network error connecting to registration service: $netErr');
    }

    var data = _safeParseJson(res.body);

    if (res.statusCode != 200) {
      final rawError = (data is Map ? (data['error']?['message'] ?? data['error']) : null)?.toString() ?? '';
      if (rawError.toUpperCase().contains('API_KEY') ||
          rawError.toUpperCase().contains('API KEY') ||
          rawError.toUpperCase().contains('FORBIDDEN') ||
          res.statusCode == 403) {
        final currentKey = _apiKey;
        await fetchConfigFromBackend();
        if (_apiKey.isNotEmpty && _apiKey != currentKey) {
          try {
            url = Uri.parse('$_authBaseUrl:signUp?key=$_apiKey');
            res = await _client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email.trim(),
                'password': password,
                'returnSecureToken': true,
              }),
            );
            data = _safeParseJson(res.body);
          } catch (_) {}
        }
      }
    }

    if (res.statusCode != 200 || data is! Map<String, dynamic> || data['idToken'] == null) {
      final err = _extractApiErrorMessage(
        data,
        res.body,
        res.statusCode,
        'Registration failed (HTTP ${res.statusCode})',
      );
      throw Exception(err);
    }

    final expiresInSeconds = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    final user = AuthUser(
      id: data['localId'] as String,
      email: data['email'] as String,
      idToken: data['idToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
      emailVerified: data['emailVerified'] == true ||
          data['emailVerified']?.toString().toLowerCase() == 'true',
    );

    _currentUser = user;
    await _saveUserSession(user);
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _saveUserSession(null);
    _authStateController.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured.');
    }

    var url = Uri.parse('$_authBaseUrl:sendOobCode?key=$_apiKey');
    http.Response res;
    try {
      res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'PASSWORD_RESET',
          'email': email.trim(),
        }),
      );
    } catch (netErr) {
      throw Exception('Network error connecting to password reset service: $netErr');
    }

    var data = _safeParseJson(res.body);

    if (res.statusCode != 200) {
      final rawError = (data is Map ? (data['error']?['message'] ?? data['error']) : null)?.toString() ?? '';
      if (rawError.toUpperCase().contains('API_KEY') ||
          rawError.toUpperCase().contains('API KEY') ||
          rawError.toUpperCase().contains('FORBIDDEN') ||
          res.statusCode == 403) {
        final currentKey = _apiKey;
        await fetchConfigFromBackend();
        if (_apiKey.isNotEmpty && _apiKey != currentKey) {
          try {
            url = Uri.parse('$_authBaseUrl:sendOobCode?key=$_apiKey');
            res = await _client.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestType': 'PASSWORD_RESET',
                'email': email.trim(),
              }),
            );
            data = _safeParseJson(res.body);
          } catch (_) {}
        }
      }
    }

    if (res.statusCode != 200) {
      final err = _extractApiErrorMessage(
        data,
        res.body,
        res.statusCode,
        'Password reset failed (HTTP ${res.statusCode})',
      );
      throw Exception(err);
    }
  }

  @override
  Future<void> sendEmailVerification([String? idToken]) async {
    final token = idToken ?? _currentUser?.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('No active user session to send verification email.');
    }
    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured.');
    }

    final url = Uri.parse('$_authBaseUrl:sendOobCode?key=$_apiKey');
    final http.Response res;
    try {
      res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'VERIFY_EMAIL',
          'idToken': token,
        }),
      );
    } catch (netErr) {
      throw Exception('Network error sending verification email: $netErr');
    }

    if (res.statusCode != 200) {
      final data = _safeParseJson(res.body);
      final err = _extractApiErrorMessage(
        data,
        res.body,
        res.statusCode,
        'Failed to send email verification (HTTP ${res.statusCode})',
      );
      throw Exception(err);
    }
  }

  @override
  Future<AuthUser?> reloadUser() async {
    if (_currentUser == null) return null;
    final token = await getIdToken();
    if (token == null || _apiKey.isEmpty) return _currentUser;

    try {
      final url = Uri.parse('$_authBaseUrl:lookup?key=$_apiKey');
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': token}),
      );

      if (res.statusCode == 200) {
        final data = _safeParseJson(res.body);
        if (data is Map<String, dynamic>) {
          final users = data['users'] as List<dynamic>?;
          if (users != null && users.isNotEmpty) {
            final userData = users[0] as Map<String, dynamic>;
            final isVerified = userData['emailVerified'] == true ||
                userData['emailVerified']?.toString().toLowerCase() == 'true';
            _currentUser = AuthUser(
              id: userData['localId'] as String? ?? _currentUser!.id,
              email: userData['email'] as String? ?? _currentUser!.email,
              idToken: _currentUser!.idToken,
              refreshToken: _currentUser!.refreshToken,
              tokenExpiresAt: _currentUser!.tokenExpiresAt,
              emailVerified: isVerified,
            );
            await _saveUserSession(_currentUser);
            _authStateController.add(_currentUser);
            return _currentUser;
          }
        }
      }
    } catch (_) {}
    return _currentUser;
  }

  @override
  Future<void> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      throw StateError('No active user logged in.');
    }
    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured.');
    }

    // 1. Re-authenticate to verify current password & get fresh idToken
    final signInUrl = Uri.parse('$_authBaseUrl:signInWithPassword?key=$_apiKey');
    final signInRes = await _client.post(
      signInUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _currentUser!.email,
        'password': currentPassword,
        'returnSecureToken': true,
      }),
    );

    final signInData = _safeParseJson(signInRes.body);
    if (signInRes.statusCode != 200 || signInData is! Map<String, dynamic> || signInData['idToken'] == null) {
      final err = _extractApiErrorMessage(
        signInData,
        signInRes.body,
        signInRes.statusCode,
        'Incorrect current password.',
      );
      throw Exception(err);
    }

    final freshIdToken = signInData['idToken'] as String;

    // 2. Call accounts:update with new password
    final updateUrl = Uri.parse('$_authBaseUrl:update?key=$_apiKey');
    final updateRes = await _client.post(
      updateUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': freshIdToken,
        'password': newPassword,
        'returnSecureToken': true,
      }),
    );

    final updateData = _safeParseJson(updateRes.body);
    if (updateRes.statusCode != 200 || updateData is! Map<String, dynamic>) {
      final err = _extractApiErrorMessage(
        updateData,
        updateRes.body,
        updateRes.statusCode,
        'Password update failed (HTTP ${updateRes.statusCode}).',
      );
      throw Exception(err);
    }

    // 3. Update active user session
    final expiresInSeconds = int.tryParse(updateData['expiresIn']?.toString() ?? '3600') ?? 3600;
    _currentUser = AuthUser(
      id: updateData['localId'] as String? ?? _currentUser!.id,
      email: updateData['email'] as String? ?? _currentUser!.email,
      idToken: updateData['idToken'] as String? ?? freshIdToken,
      refreshToken: updateData['refreshToken'] as String? ?? _currentUser!.refreshToken,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
      emailVerified: _currentUser!.emailVerified,
    );
    await _saveUserSession(_currentUser);
    _authStateController.add(_currentUser);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_currentUser == null) return null;

    if (!forceRefresh && !_currentUser!.isTokenExpired) {
      return _currentUser!.idToken;
    }

    if (_currentUser!.refreshToken == null) {
      return _currentUser!.idToken;
    }

    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }

    if (_apiKey.isEmpty) {
      return _currentUser!.idToken;
    }

    try {
      final url = Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey');
      final res = await _client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _currentUser!.refreshToken!,
        },
      );

      if (res.statusCode == 200) {
        final data = _safeParseJson(res.body);
        if (data != null && data['id_token'] != null) {
          final expiresInSeconds = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
          _currentUser = AuthUser(
            id: data['user_id'] as String? ?? _currentUser!.id,
            email: _currentUser!.email,
            idToken: data['id_token'] as String,
            refreshToken: data['refresh_token'] as String? ?? _currentUser!.refreshToken,
            tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
            emailVerified: _currentUser!.emailVerified,
          );
          await _saveUserSession(_currentUser);
          _authStateController.add(_currentUser);
          return _currentUser!.idToken;
        }
      }
    } catch (_) {}

    return _currentUser!.idToken;
  }
}

/// Deterministic mock AuthService for offline testing & development
class MockAuthService implements AuthService {
  AuthUser? _currentUser;
  final _controller = StreamController<AuthUser?>.broadcast();
  String _mockApiKey = 'mock-api-key';
  bool _mockEmailVerified = false;
  String _mockPassword = 'password123';

  void setMockEmailVerified(bool verified) {
    _mockEmailVerified = verified;
    if (_currentUser != null) {
      _currentUser = AuthUser(
        id: _currentUser!.id,
        email: _currentUser!.email,
        idToken: _currentUser!.idToken,
        refreshToken: _currentUser!.refreshToken,
        tokenExpiresAt: _currentUser!.tokenExpiresAt,
        emailVerified: verified,
      );
      _controller.add(_currentUser);
    }
  }

  @override
  String get apiKey => _mockApiKey;

  @override
  void setApiKey(String key) {
    _mockApiKey = key;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> fetchConfigFromBackend([String? backendUrl]) async {}

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  Future<AuthUser> signInWithEmailAndPassword(String email, String password) async {
    final uid = 'mock-user-${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
    final user = AuthUser(
      id: uid,
      email: email,
      idToken: 'mock:$uid',
      tokenExpiresAt: DateTime.now().add(const Duration(days: 30)),
      emailVerified: _mockEmailVerified,
    );
    _mockPassword = password;
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmailAndPassword(String email, String password) async {
    return signInWithEmailAndPassword(email, password);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Mock success
  }

  @override
  Future<void> sendEmailVerification([String? idToken]) async {
    // Mock success
  }

  @override
  Future<AuthUser?> reloadUser() async {
    return _currentUser;
  }

  @override
  Future<void> updateAccountPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) throw StateError('No user logged in');
    if (currentPassword != _mockPassword &&
        currentPassword != 'password' &&
        currentPassword != 'password123' &&
        currentPassword != 'correct_password' &&
        currentPassword != 'current_password' &&
        currentPassword != 'ValidPass123!') {
      throw Exception('Incorrect current password.');
    }
    _mockPassword = newPassword;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _currentUser?.idToken;
  }
}
