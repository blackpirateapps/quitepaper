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
    return DateTime.now().isAfter(tokenExpiresAt!);
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
        final decoded = jsonDecode(storedJson) as Map<String, dynamic>;
        _currentUser = AuthUser.fromJson(decoded);
        _authStateController.add(_currentUser);
      }
    } catch (_) {
      _currentUser = null;
    }

    if (_apiKey.isEmpty) {
      await fetchConfigFromBackend();
    }

    // Refresh token if needed upon launch
    if (_currentUser != null) {
      try {
        await getIdToken();
      } catch (_) {}
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
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final fetchedKey = data['firebaseApiKey'] as String?;
        if (fetchedKey != null && fetchedKey.trim().isNotEmpty) {
          _apiKey = fetchedKey.trim();
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
      throw StateError('Firebase API key is not configured. Supply FIREBASE_API_KEY dart-define or constructor.');
    }

    final url = Uri.parse('$_authBaseUrl:signInWithPassword?key=$_apiKey');
    final res = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final message = data['error']?['message'] ?? 'Authentication failed';
      throw Exception(message);
    }

    final expiresInSeconds = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    final user = AuthUser(
      id: data['localId'] as String,
      email: data['email'] as String,
      idToken: data['idToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
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
      throw StateError('Firebase API key is not configured.');
    }

    final url = Uri.parse('$_authBaseUrl:signUp?key=$_apiKey');
    final res = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final message = data['error']?['message'] ?? 'Registration failed';
      throw Exception(message);
    }

    final expiresInSeconds = int.tryParse(data['expiresIn']?.toString() ?? '3600') ?? 3600;
    final user = AuthUser(
      id: data['localId'] as String,
      email: data['email'] as String,
      idToken: data['idToken'] as String,
      refreshToken: data['refreshToken'] as String?,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
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
      throw StateError('Firebase API key is not configured.');
    }

    final url = Uri.parse('$_authBaseUrl:sendOobCode?key=$_apiKey');
    final res = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email.trim(),
      }),
    );

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final message = data['error']?['message'] ?? 'Password reset failed';
      throw Exception(message);
    }
  }

  @override
  Future<void> sendEmailVerification([String? idToken]) async {
    final token = idToken ?? _currentUser?.idToken;
    if (token == null || token.isEmpty) {
      throw StateError('No active user session to send verification email.');
    }
    if (_apiKey.isEmpty) {
      throw StateError('Firebase API key is not configured.');
    }

    final url = Uri.parse('$_authBaseUrl:sendOobCode?key=$_apiKey');
    final res = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requestType': 'VERIFY_EMAIL',
        'idToken': token,
      }),
    );

    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final message = data['error']?['message'] as String? ?? 'Failed to send email verification';
      if (message.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) {
        throw Exception('Too many attempts. Please try again in a few minutes.');
      }
      throw Exception(message);
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
        final data = jsonDecode(res.body) as Map<String, dynamic>;
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

    final signInData = jsonDecode(signInRes.body) as Map<String, dynamic>;
    if (signInRes.statusCode != 200) {
      final errorMsg = signInData['error']?['message'] as String? ?? '';
      if (errorMsg.contains('INVALID_PASSWORD') ||
          errorMsg.contains('INVALID_LOGIN_CREDENTIALS')) {
        throw Exception('Incorrect current password.');
      } else if (errorMsg.contains('NETWORK_ERROR') || errorMsg.contains('network-request-failed')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (errorMsg.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) {
        throw Exception('Too many attempts. Please try again later.');
      }
      throw Exception('Incorrect current password.');
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

    final updateData = jsonDecode(updateRes.body) as Map<String, dynamic>;
    if (updateRes.statusCode != 200) {
      final errorMsg = updateData['error']?['message'] as String? ?? 'Password update failed';
      if (errorMsg.contains('WEAK_PASSWORD')) {
        throw Exception('Password should be at least 8 characters.');
      } else if (errorMsg.contains('CREDENTIAL_TOO_OLD_LOGIN_AGAIN') || errorMsg.contains('requires-recent-login')) {
        throw Exception('Session expired. Please sign in again.');
      }
      throw Exception(errorMsg);
    }

    // 3. Update active user session
    final expiresInSeconds = int.tryParse(updateData['expiresIn']?.toString() ?? '3600') ?? 3600;
    _currentUser = AuthUser(
      id: updateData['localId'] as String? ?? _currentUser!.id,
      email: updateData['email'] as String? ?? _currentUser!.email,
      idToken: updateData['idToken'] as String? ?? freshIdToken,
      refreshToken: updateData['refreshToken'] as String? ?? _currentUser!.refreshToken,
      tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
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

    if (_currentUser!.refreshToken == null || _apiKey.isEmpty) {
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
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final expiresInSeconds = int.tryParse(data['expires_in']?.toString() ?? '3600') ?? 3600;
        _currentUser = AuthUser(
          id: data['user_id'] as String? ?? _currentUser!.id,
          email: _currentUser!.email,
          idToken: data['id_token'] as String,
          refreshToken: data['refresh_token'] as String? ?? _currentUser!.refreshToken,
          tokenExpiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
          emailVerified: _currentUser!.emailVerified,
        );
        await _saveUserSession(_currentUser);
        _authStateController.add(_currentUser);
        return _currentUser!.idToken;
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
