import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/cli/cli_attachments.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/cli/cli_sync.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'cli_attachments_test.dart' show TestCredentials;

void main() {
  test(
    'uploads encrypted image, confirms metadata, pushes note and references',
    () async {
      final root = await Directory.systemTemp.createTemp('qp-image-sync-test-');
      final db = CliDatabase.open('${root.path}/quiet_paper.sqlite');
      try {
        final credentials = TestCredentials(root);
        final image = File('${root.path}/photo.png');
        await image.writeAsBytes(img.encodePng(img.Image(width: 3, height: 2)));
        final service = CliAttachments(db, credentials);
        final note = await service.save(
          title: 'Photo',
          content: '',
          files: [image.path],
        );
        final attachment = service.list(note).single;
        final calls = <String>[];
        final client = MockClient((request) async {
          final path = request.url.path;
          calls.add(path);
          Map<String, dynamic> response;
          switch (path) {
            case '/api/v1/keys':
              response = {
                'keyAuthCommitment': DefaultCryptoService()
                    .computeKeyAuthCommitment(credentials.key),
              };
            case '/api/v1/attachments/upload-auth':
              response = {
                'uploadUrl': 'https://upload.example/raw',
                'publicId': 'asset',
                'apiKey': 'public',
                'timestamp': 123,
                'signature': 'signed',
              };
            case '/raw':
              expect(request.headers.containsKey('authorization'), false);
              expect(latin1.decode(request.bodyBytes), contains('QPA1'));
              response = {
                'public_id': 'asset',
                'secure_url': 'https://upload.example/asset',
              };
            case '/api/v1/attachments/confirm':
              final body = jsonDecode(request.body) as Map;
              expect(body['attachmentId'], attachment['id']);
              expect(body['noteId'], note.id);
              expect(body['fileName'], 'photo.png');
              response = {
                'attachment': {'serverRevision': 4},
              };
            case '/api/v1/sync/push':
              response = {
                'results': [
                  {'id': note.id, 'revision': 5},
                ],
                'conflicts': [],
              };
            case '/api/v1/sync/references':
              final body = jsonDecode(request.body) as Map;
              expect(
                (body['references'] as List).single['resourceId'],
                attachment['id'],
              );
              response = {'success': true};
            default:
              throw StateError('Unexpected request $path');
          }
          return http.Response(jsonEncode(response), 200);
        });
        final sync = CliSync(db, credentials, client: client);
        await sync.syncNote(note.id);
        sync.close();
        expect(calls, [
          '/api/v1/keys',
          '/api/v1/attachments/upload-auth',
          '/raw',
          '/api/v1/attachments/confirm',
          '/api/v1/sync/push',
          '/api/v1/sync/references',
        ]);
        expect(service.list(note).single['server_revision'], 4);
        expect(service.list(note).single['upload_state'], 'synced');
        expect(
          db.connection.select('SELECT is_dirty FROM notes').single['is_dirty'],
          0,
        );
      } finally {
        db.close();
        await root.delete(recursive: true);
      }
    },
  );
}
