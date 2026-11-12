import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../crypto/crypto_service.dart';
import 'cli_attachments.dart';
import 'cli_credentials.dart';
import 'cli_database.dart';

/// Uploads local note snapshots and their image attachments using the existing
/// E2EE protocol. Conflicts remain dirty for resolution by the desktop merge UI.
/// Does not advance the desktop pull cursor or replace remote changes locally.
class CliSync {
  CliSync(this.db, this.credentials, {http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          Platform.environment['QP_API_URL'] ??
          'https://quitepaper.vercel.app';
  final CliDatabase db;
  final CliCredentials credentials;
  final http.Client client;
  final String baseUrl;
  String? _token;
  Map<String, dynamic>? _session;
  String? _deviceId;
  static const timeout = Duration(seconds: 30);

  Future<void> authenticate({bool refresh = false}) async {
    final stored = (await credentials.read())['quietpaper_auth_session_v1'];
    if (stored == null) {
      throw StateError(
        'No account session. Sign in to Quiet Paper on this Linux account first.',
      );
    }
    _session ??= jsonDecode(stored) as Map<String, dynamic>;
    try {
      final rows = db.connection.select(
        "SELECT value FROM sync_metadata WHERE key='device_id'",
      );
      if (rows.isNotEmpty) _deviceId = rows.first['value'] as String;
    } catch (_) {
      /* A CLI-created notebook may not have sync metadata yet. */
    }
    final expires = DateTime.tryParse(
      _session!['tokenExpiresAt'] as String? ?? '',
    );
    if (!refresh &&
        expires != null &&
        expires.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      _token = _session!['idToken'] as String;
      return;
    }
    final refreshToken = _session!['refreshToken'] as String?;
    if (refreshToken == null) {
      throw StateError('Session expired. Sign in to Quiet Paper again.');
    }
    final configResponse = await client
        .get(Uri.parse('$baseUrl/api/v1/config'))
        .timeout(timeout);
    final config = decode(configResponse);
    final apiKey = config['firebaseApiKey'] as String?;
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Backend did not supply an authentication configuration.',
      );
    }
    final response = await client
        .post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
          body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
        )
        .timeout(timeout);
    final data = decode(response);
    if (data['user_id'] != _session!['id']) {
      throw StateError('Authentication account mismatch.');
    }
    _token = data['id_token'] as String;
  }

  static Map<String, dynamic> decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Do not print bodies that may contain credentials or private server data.
      throw HttpException('Request failed (HTTP ${response.statusCode}).');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (_token == null) await authenticate();
    Future<http.Response> send() {
      final headers = {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'X-Device-Id': ?_deviceId,
      };
      final uri = Uri.parse('$baseUrl$path');
      return (body == null
              ? client.get(uri, headers: headers)
              : client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(timeout);
    }

    var response = await send();
    if (response.statusCode == 401) {
      await authenticate(refresh: true);
      response = await send();
    }
    return decode(response);
  }

  Future<void> syncNote(String noteId) async {
    final rows = db.connection.select('SELECT * FROM notes WHERE id=?', [
      noteId,
    ]);
    if (rows.isEmpty) return;
    final snapshot = Map<String, Object?>.from(rows.single);
    final note = db.getNoteByIdOrPrefix(noteId)!;
    final key = await credentials.masterKey();
    final crypto = DefaultCryptoService();
    final remoteKeys = await request('/api/v1/keys');
    final commitment = remoteKeys['keyAuthCommitment'];
    final wrapped = (await credentials
        .read())['quietpaper_wrapped_master_key_v1'];
    final localWrapped = wrapped == null ? null : jsonDecode(wrapped) as Map;
    if (commitment != null
        ? commitment != crypto.computeKeyAuthCommitment(key)
        : localWrapped == null ||
              localWrapped['wrappedMasterKey'] !=
                  remoteKeys['wrappedMasterKey']) {
      throw StateError(
        'Local encryption keys do not match this cloud account. Unlock/sync in the desktop app first.',
      );
    }
    final attachments = CliAttachments(db, credentials).list(note);
    for (final attachment in attachments) {
      if (attachment['is_dirty'] == 1 ||
          attachment['upload_state'] != 'synced') {
        await upload(attachment);
      }
    }
    final envelope = await crypto.encryptNote(
      plaintext: NotePlaintext(
        title: note.title,
        body: note.content,
        tags: note.tags,
        pinnedTags: snapshot['pinned_tags'] == null
            ? []
            : (jsonDecode(snapshot['pinned_tags'] as String) as List)
                  .cast<String>(),
      ),
      masterKeyBytes: key,
      noteId: note.id,
    );
    final queueIds = db.connection
        .select('SELECT id FROM sync_queue WHERE note_id=?', [note.id])
        .map((r) => r['id'])
        .toList();
    final response = await request('/api/v1/sync/push', {
      'idempotencyKey': 'cli_${const Uuid().v4()}',
      if (_deviceId != null) 'deviceId': _deviceId,
      'changes': [
        {
          'id': note.id,
          'createdAt': note.createdAt.toUtc().toIso8601String(),
          'updatedAt': note.updatedAt.toUtc().toIso8601String(),
          'archived': note.isArchived,
          'trashed': note.isTrashed,
          'pinned': note.isPinned,
          'contentCiphertext': envelope.ciphertext,
          'contentNonce': envelope.nonce,
          'contentVersion': envelope.contentVersion,
          'encryptionKeyVersion': envelope.keyVersion,
          if ((snapshot['server_revision'] as int) > 0)
            'baseRevision': snapshot['server_revision'],
          'isDeleted': false,
          if (snapshot['deleted_at'] != null)
            'deletedAt': DateTime.fromMillisecondsSinceEpoch(
              (snapshot['deleted_at'] as int) * 1000,
              isUtc: true,
            ).toIso8601String(),
        },
      ],
    });
    if ((response['conflicts'] as List? ?? []).isNotEmpty) {
      throw StateError(
        'Remote note conflict. Local changes are pending; resolve it in the desktop app.',
      );
    }
    final results = response['results'] as List? ?? [];
    final result = results
        .cast<Map>()
        .where((r) => r['id'] == note.id)
        .firstOrNull;
    if (result == null || result['revision'] is! int) {
      throw StateError('Server did not acknowledge the note.');
    }
    // Advance the base even if reference projection fails, without clearing dirty state.
    db.connection.execute(
      'UPDATE notes SET server_revision=? WHERE id=? AND server_revision=?',
      [result['revision'], note.id, snapshot['server_revision']],
    );
    final references = RegExp(r'qp://(asset|document)/([0-9a-fA-F-]{36})')
        .allMatches(note.content)
        .map(
          (m) => {
            'resourceType': m[1] == 'asset' ? 'attachment' : 'document',
            'resourceId': m[2],
            'noteId': note.id,
          },
        )
        .toList();
    if (references.isNotEmpty) {
      await request('/api/v1/sync/references', {
        'references': references,
        if (_deviceId != null) 'deviceId': _deviceId,
      });
    }
    db.transaction(() {
      // A GUI edit during HTTP requests must remain dirty and retain its queue entry.
      final current = db.connection.select('SELECT * FROM notes WHERE id=?', [
        note.id,
      ]);
      if (current.isEmpty) return;
      for (final column in [
        'title',
        'content',
        'updated_at',
        'is_pinned',
        'is_archived',
        'is_trashed',
        'deleted_at',
        'pinned_tags',
      ]) {
        if (current.single[column] != snapshot[column]) return;
      }
      if (current.single['server_revision'] != result['revision']) return;
      db.connection.execute(
        'UPDATE notes SET is_dirty=0,synced_at=? WHERE id=?',
        [DateTime.now().millisecondsSinceEpoch ~/ 1000, note.id],
      );
      for (final id in queueIds) {
        db.connection.execute('DELETE FROM sync_queue WHERE id=?', [id]);
      }
    });
  }

  Future<void> upload(Map<String, Object?> row) async {
    final path = row['local_path'] as String?;
    if (path == null || !await File(path).exists()) {
      throw StateError('An attachment has no local encrypted payload.');
    }
    final metadata = <String, dynamic>{
      'attachmentId': row['id'],
      'noteId': row['note_id'],
      'mimeType': row['mime_type'],
      'byteSize': row['byte_size'],
      'sha256': row['sha256'],
    };
    final auth = await request('/api/v1/attachments/upload-auth', {
      ...metadata,
      'variant': 'original',
    });
    final uri = Uri.parse(
      auth['uploadUrl'] as String? ??
          'https://api.cloudinary.com/v1_1/${auth['cloudName']}/raw/upload',
    );
    if (uri.scheme != 'https') {
      throw StateError('Attachment upload requires HTTPS.');
    }
    final upload = http.MultipartRequest('POST', uri)
      ..fields.addAll({
        'api_key': auth['apiKey'] as String,
        'timestamp': '${auth['timestamp']}',
        'signature': auth['signature'] as String,
        'public_id': auth['publicId'] as String,
        if (auth['folder'] != null) 'folder': auth['folder'] as String,
      });
    upload.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await File(path).readAsBytes(),
        filename: auth['publicId'] as String,
      ),
    );
    final result = decode(
      await http.Response.fromStream(
        await client.send(upload).timeout(timeout),
      ).timeout(timeout),
    );
    final confirmed = await request('/api/v1/attachments/confirm', {
      ...metadata,
      'fileName': row['file_name'],
      'kind': row['kind'],
      'cloudPublicId': result['public_id'],
      'cloudUrl': result['secure_url'],
    });
    db.connection.execute(
      '''UPDATE attachments SET is_dirty=0,upload_state='synced',
      server_revision=?,synced_at=?,cloud_public_id=?,cloud_url=? WHERE id=? AND updated_at=? AND is_deleted=0''',
      [
        (confirmed['attachment'] as Map?)?['serverRevision'] ?? 1,
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        result['public_id'],
        result['secure_url'],
        row['id'],
        row['updated_at'],
      ],
    );
  }

  void close() => client.close();
}
