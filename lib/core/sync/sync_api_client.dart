import 'dart:convert';
import 'package:http/http.dart' as http;
import '../attachments/attachment_models.dart';
import '../auth/auth_service.dart';
import '../crypto/crypto_service.dart';
import '../documents/document_models.dart';
import 'sync_models.dart';

abstract class SyncApiClient {
  String get baseUrl => 'https://quitepaper.vercel.app';
  void setBaseUrl(String url) {}

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
  Future<CloudinaryUploadAuth> getDocumentUploadAuth({
    required String documentId,
    String? noteId,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  });
  Future<Map<String, dynamic>> confirmDocumentUpload({
    required String documentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  });
  Future<DocumentSyncPayload?> getDocumentMetadata(String documentId);
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  });
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  });
  Future<PullChangeItem?> getHistoricalRevision({
    required String noteId,
    required int revision,
  });
  Future<PullChangeItem?> getRemoteNote({
    required String noteId,
  });
  Future<void> syncReferences({
    required List<SyncReferenceItem> references,
    String? deviceId,
  }) async {}
  Future<StorageProfileReport> getStorageProfile() async {
    return const StorageProfileReport(
      userId: '',
      generatedAt: '',
      totalEstimatedBytes: 0,
      totalReclaimableBytes: 0,
      safeSyncBoundaryRevision: 0,
      activeDevicesCount: 0,
      staleDevicesCount: 0,
      expiredDevicesCount: 0,
      tables: {},
    );
  }
  Future<GcExecutionSummary> runGarbageCollection({
    bool dryRun = false,
    int batchSize = 100,
  }) async {
    return const GcExecutionSummary(
      runId: '',
      userId: '',
      dryRun: false,
      startedAt: '',
      finishedAt: '',
      durationMs: 0,
      safeSyncBoundaryRevision: 0,
      syncChangesDeleted: 0,
      noteVersionsDeleted: 0,
      idempotencyKeysDeleted: 0,
      orphanedAttachmentsIdentified: 0,
      orphanedDocumentsIdentified: 0,
      destructionJobsCreated: 0,
      destructionJobsProcessed: 0,
      destructionJobsCompleted: 0,
      destructionJobsFailed: 0,
      tombstonesCleaned: 0,
      estimatedBytesReclaimed: 0,
    );
  }
  Future<StorageResourcesResponse> getStorageResources() async {
    return const StorageResourcesResponse(
      attached: [],
      orphaned: [],
      totalAttachedCount: 0,
      totalOrphanedCount: 0,
      totalStorageBytes: 0,
    );
  }
  Future<void> deleteStorageResource({
    required String resourceType,
    required String resourceId,
  }) async {}
  Future<void> permanentDeleteNote(String noteId) async {}
}

class HttpSyncApiClient implements SyncApiClient {
  HttpSyncApiClient({
    required this.authService,
    String? baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = (baseUrl ??
            const String.fromEnvironment('SYNC_API_URL',
                defaultValue: 'https://quitepaper.vercel.app'))
        .trim().replaceAll(RegExp(r'/+$'), ''),
        _client = httpClient ?? http.Client();

  final AuthService authService;
  String _baseUrl;
  final http.Client _client;

  @override
  String get baseUrl => _baseUrl;

  @override
  void setBaseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

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

  Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) sendRequest,
  ) async {
    var headers = await _authHeaders();
    var response = await sendRequest(headers);

    if (response.statusCode == 401) {
      // Intercept 401: Token might be expired or invalid on server.
      // Force-refresh token via Firebase SecureToken API and retry once.
      final freshToken = await authService.getIdToken(forceRefresh: true);
      if (freshToken != null && freshToken.isNotEmpty) {
        headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $freshToken',
        };
        response = await sendRequest(headers);
      }
    }

    return response;
  }

  static Map<String, dynamic>? _safeParseJson(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String _extractErrorMessage(http.Response res, String defaultPrefix) {
    final trimmed = res.body.trim();
    if (trimmed.startsWith('{')) {
      try {
        final errJson = jsonDecode(trimmed);
        if (errJson is Map && errJson['error'] is Map && errJson['error']['message'] != null) {
          return '$defaultPrefix: ${errJson['error']['message']}';
        }
        if (errJson is Map && errJson['message'] != null) {
          return '$defaultPrefix: ${errJson['message']}';
        }
      } catch (_) {}
    }

    // Guard against HTML error payloads leaking into UI
    if (trimmed.startsWith('<') ||
        trimmed.toUpperCase().contains('<!DOCTYPE HTML') ||
        trimmed.toUpperCase().contains('<HTML')) {
      if (res.statusCode == 401) {
        return '$defaultPrefix: Authentication failed (401). Please sign in again.';
      }
      if (res.statusCode == 404) {
        return '$defaultPrefix: Server endpoint not found (404). Please check your sync server URL.';
      }
      if (res.statusCode >= 500) {
        return '$defaultPrefix: Sync server is temporarily unavailable (${res.statusCode}). Please try again later.';
      }
      return '$defaultPrefix (${res.statusCode}): Server returned an unexpected HTML response';
    }

    final truncated = trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
    return '$defaultPrefix (${res.statusCode}): $truncated';
  }

  @override
  Future<Map<String, dynamic>> getAccount() async {
    final url = Uri.parse('$_baseUrl/api/v1/account');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to get account'));
    }
    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to get account: Invalid JSON response from server');
    }
    return data;
  }

  @override
  Future<WrappedMasterKeyData?> getKeys() async {
    final url = Uri.parse('$_baseUrl/api/v1/keys');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode == 404) {
      return null;
    }
    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch keys'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to fetch keys: Invalid JSON response from server');
    }
    return WrappedMasterKeyData.fromJson(data);
  }

  @override
  Future<WrappedMasterKeyData> putKeys(WrappedMasterKeyData keyData) async {
    final url = Uri.parse('$_baseUrl/api/v1/keys');
    final body = jsonEncode(keyData.toJson());
    final res = await _sendWithAuthRetry((headers) => _client.put(
      url,
      headers: headers,
      body: body,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to save keys'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to save keys: Invalid JSON response from server');
    }
    return WrappedMasterKeyData.fromJson(data);
  }

  @override
  Future<PushSyncResponse> pushChanges({
    required List<NoteSyncPayload> changes,
    String? idempotencyKey,
    String? deviceId,
  }) async {
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

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Push sync failed'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Push sync failed: Invalid JSON response from server');
    }
    return PushSyncResponse.fromJson(data);
  }

  @override
  Future<PullSyncResponse> pullChanges({
    required int cursor,
    int limit = 100,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/pull');
    final body = jsonEncode({
      'cursor': cursor,
      'limit': limit,
    });

    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: body,
    ));

    if (res.statusCode == 410) {
      final parsed = _safeParseJson(res.body);
      final errCode = parsed?['error']?['code'] as String?;
      final details = parsed?['error']?['details'] as Map<String, dynamic>?;
      if (errCode == 'SYNC_CURSOR_EXPIRED' || details?['cursorExpired'] == true) {
        throw SyncCursorExpiredException(
          message: parsed?['error']?['message'] as String? ?? 'Sync cursor has expired',
          minRetainedRevision: details?['minRetainedRevision'] as int? ?? 0,
          currentRevision: details?['currentRevision'] as int? ?? 0,
        );
      }
    }

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Pull sync failed'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Pull sync failed: Invalid JSON response from server');
    }
    return PullSyncResponse.fromJson(data);
  }

  @override
  Future<int> getCursor() async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/cursor');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to get cursor'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to get cursor: Invalid JSON response from server');
    }
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

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to obtain attachment upload auth'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to obtain attachment upload auth: Invalid JSON response');
    }
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

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to confirm attachment upload'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to confirm attachment upload: Invalid JSON response');
    }
    return data;
  }

  @override
  Future<AttachmentSyncPayload?> getAttachmentMetadata(String attachmentId) async {
    final url = Uri.parse('$_baseUrl/api/v1/attachments/$attachmentId');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode == 200) {
      final data = _safeParseJson(res.body);
      if (data == null) {
        throw Exception('Failed to fetch attachment metadata: Invalid JSON response');
      }
      return AttachmentSyncPayload.fromJson(data);
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch attachment metadata'));
    }
  }

  @override
  Future<CloudinaryUploadAuth> getDocumentUploadAuth({
    required String documentId,
    String? noteId,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/documents/upload-auth');
    final body = <String, dynamic>{
      'documentId': documentId,
      'title': title,
      'mimeType': mimeType,
      'byteSize': byteSize,
      'pageCount': pageCount,
      'sha256': sha256,
    };
    if (noteId != null) {
      body['noteId'] = noteId;
    }

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to obtain document upload auth'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to obtain document upload auth: Invalid JSON response');
    }
    return CloudinaryUploadAuth.fromJson(data);
  }

  @override
  Future<Map<String, dynamic>> confirmDocumentUpload({
    required String documentId,
    String? noteId,
    required String cloudPublicId,
    required String cloudUrl,
    String title = 'Scanned Document',
    String mimeType = 'application/pdf',
    int byteSize = 0,
    int pageCount = 1,
    String sha256 = '',
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/documents/confirm');
    final body = <String, dynamic>{
      'documentId': documentId,
      'cloudPublicId': cloudPublicId,
      'cloudUrl': cloudUrl,
      'title': title,
      'mimeType': mimeType,
      'byteSize': byteSize,
      'pageCount': pageCount,
      'sha256': sha256,
    };
    if (noteId != null) {
      body['noteId'] = noteId;
    }

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to confirm document upload with backend'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to confirm document upload: Invalid JSON response');
    }
    return data;
  }

  @override
  Future<DocumentSyncPayload?> getDocumentMetadata(String documentId) async {
    final url = Uri.parse('$_baseUrl/api/v1/documents/$documentId');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode == 200) {
      final data = _safeParseJson(res.body);
      if (data == null) {
        throw Exception('Failed to fetch document metadata: Invalid JSON response');
      }
      return DocumentSyncPayload.fromJson(data);
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch document metadata'));
    }
  }

  @override
  Future<PushVersionSyncResponse> pushVersions({
    required List<NoteVersionSyncPayload> versions,
    String? deviceId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/versions/push');
    final body = {
      'versions': versions.map((v) => v.toJson()).toList(),
      'deviceId': ?deviceId,
    };

    final encoded = jsonEncode(body);
    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: encoded,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to push note versions'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to push note versions: Invalid JSON response');
    }
    return PushVersionSyncResponse.fromJson(data);
  }

  @override
  Future<PullVersionSyncResponse> pullVersions({
    required int cursor,
    int limit = 100,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/versions/pull?cursor=$cursor&limit=$limit');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to pull note versions'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to pull note versions: Invalid JSON response');
    }
    return PullVersionSyncResponse.fromJson(data);
  }

  @override
  Future<PullChangeItem?> getHistoricalRevision({
    required String noteId,
    required int revision,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/notes/$noteId/revisions/$revision');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode == 200) {
      final data = _safeParseJson(res.body);
      if (data == null) {
        throw Exception('Failed to fetch historical revision: Invalid JSON response');
      }
      return PullChangeItem.fromJson(data);
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch historical revision'));
    }
  }

  @override
  Future<PullChangeItem?> getRemoteNote({
    required String noteId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/notes/$noteId');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode == 200) {
      final data = _safeParseJson(res.body);
      if (data == null) {
        throw Exception('Failed to fetch remote note: Invalid JSON response');
      }
      return PullChangeItem.fromJson(data);
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch remote note'));
    }
  }

  @override
  Future<void> syncReferences({
    required List<SyncReferenceItem> references,
    String? deviceId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/sync/references');
    final body = jsonEncode({
      'deviceId': ?deviceId,
      'references': references.map((r) => r.toJson()).toList(),
    });

    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: body,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to synchronize resource references'));
    }
  }

  @override
  Future<StorageProfileReport> getStorageProfile() async {
    final url = Uri.parse('$_baseUrl/api/v1/storage/profile');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch storage profile'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to fetch storage profile: Invalid JSON response');
    }
    return StorageProfileReport.fromJson(data);
  }

  @override
  Future<GcExecutionSummary> runGarbageCollection({
    bool dryRun = false,
    int batchSize = 100,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/storage/gc');
    final body = jsonEncode({
      'dryRun': dryRun,
      'batchSize': batchSize,
    });

    final res = await _sendWithAuthRetry((headers) => _client.post(
      url,
      headers: headers,
      body: body,
    ));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to execute garbage collection'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to execute garbage collection: Invalid JSON response');
    }
    return GcExecutionSummary.fromJson(data);
  }

  @override
  Future<StorageResourcesResponse> getStorageResources() async {
    final url = Uri.parse('$_baseUrl/api/v1/storage/resources');
    final res = await _sendWithAuthRetry((headers) => _client.get(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to fetch storage resources'));
    }

    final data = _safeParseJson(res.body);
    if (data == null) {
      throw Exception('Failed to fetch storage resources: Invalid JSON response');
    }
    return StorageResourcesResponse.fromJson(data);
  }

  @override
  Future<void> deleteStorageResource({
    required String resourceType,
    required String resourceId,
  }) async {
    final url = Uri.parse('$_baseUrl/api/v1/storage/resources/$resourceType/$resourceId');
    final res = await _sendWithAuthRetry((headers) => _client.delete(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to delete storage resource'));
    }
  }

  @override
  Future<void> permanentDeleteNote(String noteId) async {
    final url = Uri.parse('$_baseUrl/api/v1/notes/$noteId/permanent-delete');
    final res = await _sendWithAuthRetry((headers) => _client.post(url, headers: headers));

    if (res.statusCode != 200) {
      throw Exception(_extractErrorMessage(res, 'Failed to permanently delete note'));
    }
  }
}
