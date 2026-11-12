import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/cli/cli_sync.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'cli_attachments_test.dart' show TestCredentials;

void main() {
  late Directory root;
  late CliDatabase db;
  late TestCredentials credentials;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('qp-sync-test-');
    db = CliDatabase.open('${root.path}/quiet_paper.sqlite');
    credentials = TestCredentials(root);
  });
  tearDown(() async {
    db.close();
    await root.delete(recursive: true);
  });

  for (final mode in ['success', 'offline', 'conflict', 'concurrent']) {
    test('note sync handles $mode without losing local edits', () async {
      final note = db.createNote(
        title: 'Private title',
        content: 'Private body #tag',
      );
      final crypto = DefaultCryptoService();
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (mode == 'offline') throw const SocketException('offline');
        if (request.url.path.endsWith('/keys')) {
          return http.Response(
            jsonEncode({
              'keyAuthCommitment': crypto.computeKeyAuthCommitment(
                credentials.key,
              ),
            }),
            200,
          );
        }
        expect(request.url.path, '/api/v1/sync/push');
        expect(request.body, isNot(contains('Private body')));
        final body = jsonDecode(request.body) as Map;
        final change = (body['changes'] as List).single as Map;
        final plaintext = await crypto.decryptNote(
          envelope: EncryptedEnvelope(
            version: 1,
            algorithm: 'xchacha20-poly1305',
            keyVersion: 1,
            nonce: change['contentNonce'] as String,
            ciphertext: change['contentCiphertext'] as String,
          ),
          masterKeyBytes: credentials.key,
          noteId: note.id,
        );
        expect(plaintext.body, note.content);
        if (mode == 'concurrent') {
          db.updateNote(
            id: note.id,
            title: note.title,
            content: 'new GUI edit',
          );
        }
        return http.Response(
          jsonEncode({
            'results': mode == 'conflict'
                ? []
                : [
                    {'id': note.id, 'revision': 2},
                  ],
            'conflicts': mode == 'conflict'
                ? [
                    {'id': note.id},
                  ]
                : [],
          }),
          200,
        );
      });
      final sync = CliSync(db, credentials, client: client);
      if (mode == 'offline' || mode == 'conflict') {
        await expectLater(
          sync.syncNote(note.id),
          throwsA(anyOf(isA<Exception>(), isA<StateError>())),
        );
      } else {
        await sync.syncNote(note.id);
      }
      final row = db.connection.select('SELECT * FROM notes').single;
      expect(row['is_dirty'], mode == 'success' ? 0 : 1);
      expect(
        row['content'],
        mode == 'concurrent' ? 'new GUI edit' : note.content,
      );
      expect(
        db.connection.select('SELECT * FROM sync_queue').isEmpty,
        mode == 'success',
      );
      sync.close();
    });
  }
}
