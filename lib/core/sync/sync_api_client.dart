import 'dart:convert';
import 'package:http/http.dart' as http;
import '../attachments/attachment_models.dart';
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
  Future<CloudinaryUploadAuth> getAttachmentUploadAuth({
    required String attachmentId,
    String? noteId,
    String mimeType = 'image/png',
    int byteSize = 0,
    String sha256 = '',
    String variant = 'original',
  });
  Future<Map<String, dynamic>> confirmAttachmentUpload({
    required String attachmentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    int byteSize = 0,
    String sha256 = '',
  });
  Future<AttachmentSyncPayload?> getAttachmentMetadata(String attachmentId);
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  });
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  });
}

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient({
    required this.authService,
    String? baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl ??
            const String.fromEnvironment('SYNC_API_URL',
                defaultValue: 'https://quitepaper.vercel.app'),
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

  @override
  Future<CloudinaryUploadAuth> getAttachmentUploadAuth({
    required String attachmentId,
    String? noteId,
    String mimeType = 'image/png',
    int byteSize = 0,
    String sha256 = '',
    String variant = 'original',
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/attachments/upload-auth');
    final body = <String, dynamic>{
      'attachmentId': attachmentId,
      'mimeType': mimeType,
      'byteSize': byteSize,
      'sha256': sha256,
      'variant': variant,
    };
    if (noteId != null) {
      body['noteId'] = noteId;
    }

    final res = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      var message = 'Failed to obtain attachment upload auth (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson is Map && errJson['error'] is Map && errJson['error']['message'] != null) {
          message = errJson['error']['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return CloudinaryUploadAuth.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> confirmAttachmentUpload({
    required String attachmentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    int byteSize = 0,
    String sha256 = '',
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/attachments/confirm');
    final body = <String, dynamic>{
      'attachmentId': attachmentId,
      'cloudPublicId': cloudPublicId,
      'cloudUrl': cloudUrl,
      'byteSize': byteSize,
      'sha256': sha256,
    };
    if (noteId != null) {
      body['noteId'] = noteId;
    }

    final res = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      var message = 'Failed to confirm attachment upload (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson is Map && errJson['error'] is Map && errJson['error']['message'] != null) {
          message = errJson['error']['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  @override
  Future<AttachmentSyncPayload?> getAttachmentMetadata(String attachmentId) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/attachments/$attachmentId');
    final res = await _client.get(url, headers: headers);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AttachmentSyncPayload.fromJson(data);
    } else if (res.statusCode == 404) {
      return null;
    } else {
      var message = 'Failed to fetch attachment metadata (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson is Map && errJson['error'] is Map && errJson['error']['message'] != null) {
          message = errJson['error']['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  @override
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/sync/versions/push');
    final body = {
      'versions': versions.map((v) => v.toJson()).toList(),
      'deviceId': ?deviceId,
    };

    final res = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to push note versions: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PushVersionSyncResponse.fromJson(data);
  }

  @override
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$_baseUrl/api/v1/sync/versions/pull?cursor=$cursor&limit=$limit');
    final res = await _client.get(url, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('Failed to pull note versions: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PullVersionSyncResponse.fromJson(data);
  }
}
