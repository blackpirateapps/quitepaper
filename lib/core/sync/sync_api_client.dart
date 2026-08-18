import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../crypto/crypto_service.dart';
import 'sync_models.dart';

abstract class SyncApiClient {
  Future<Map<String, dynamic>> getAccount();
  Future<WrappedMasterKeyData?> getKeys();
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData);
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  });
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  });
  Future<int> getCursor();
}

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient({
    required this.authService,
    String? baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl ??
            const String.fromEnvironment('SYNC_API_URL',
                defaultValue: 'http://localhost:3000'),
        _client = httpClient ?? http.Client();

  final AuthService authService;
  final String _baseUrl;
  final http.Client _client;

  Future<Map<String, String>> _authHeaders() async {
    final token = await authService.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<Map<String, dynamic>> getAccount() async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/account');
    final res = await _client.get(url, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('Failed to get account: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<WrappedMasterKeyData?> getKeys() async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/keys');
    final res = await _client.get(url, headers: headers);

    if (res.statusCode == 404) {
      return null;
    }
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch keys: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return WrappedMasterKeyData.fromJson(data);
  }

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/keys');
    final res = await _client.put(
      url,
      headers: headers,
      body: jsonEncode(keyData.toJson()),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to save keys: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return WrappedMasterKeyData.fromJson(data);
  }

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/sync/push');
    final body = <String, dynamic>{
      'changes': changes.map((c) => c.toJson()).toList(),
    };
    if (idempotencyKey != null) {
      body['idempotencyKey'] = idempotencyKey;
    }
    if (deviceId != null) {
      body['deviceId'] = deviceId;
    }

    final res = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Push sync failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PushSyncResponse.fromJson(data);
  }

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/sync/pull');
    final body = {
      'cursor': cursor,
      'limit': limit,
    };

    final res = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Pull sync failed: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PullSyncResponse.fromJson(data);
  }

  @override
  Future<int> getCursor() async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/sync/cursor');
    final res = await _client.get(url, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('Failed to get cursor: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['cursor'] as int? ?? 0;
  }
}
