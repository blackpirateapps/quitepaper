import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.idToken,
    this.refreshToken,
    this.tokenExpiresAt,
  });

  final String id;
  final String email;
  final String idToken;
  final String? refreshToken;
  final DateTime? tokenExpiresAt;

  bool get isTokenExpired {
    if (tokenExpiresAt == null) return false;
    return DateTime.now().isAfter(tokenExpiresAt!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'tokenExpiresAt': tokenExpiresAt?.toIso8601String(),
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
    );
  }
}

abstract class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  String get apiKey;
  void setApiKey(String key);
  Future<void> fetchConfigFromBackend(String backendUrl);

  Future<AuthUser> signInWithEmailAndPassword(String email, String password);
  Future<AuthUser> signUpWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
  Future<String?> getIdToken({bool forceRefresh = false});
}

/// Universal Firebase Auth client using official Firebase REST Auth API (cross-platform, zero native crash risk)
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    String? apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey ??
            const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
        _client = httpClient ?? http.Client();

  String _apiKey;
  final http.Client _client;

  @override
  String get apiKey => _apiKey;

  @override
  void setApiKey(String key) {
    _apiKey = key.trim();
  }

  @override
  Future<void> fetchConfigFromBackend(String backendUrl) async {
    if (backendUrl.trim().isEmpty) return;
    try {
      final sanitized = backendUrl.replaceAll(RegExp(r'/+$'), '');
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
    );

    _currentUser = user;
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
    );

    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
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
        );
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

  @override
  String get apiKey => _mockApiKey;

  @override
  void setApiKey(String key) {
    _mockApiKey = key;
  }

  @override
  Future<void> fetchConfigFromBackend(String backendUrl) async {}

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
    );
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
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _currentUser?.idToken;
  }
}
