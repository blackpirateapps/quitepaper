import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/email_import/domain/note_import_source.dart';

void main() {
  final binary = Platform.environment['QP_RUST_CLI_BIN'];
  group('Rust encrypted upload sync', () {
    late Directory root;
    late String path;
    late CliDatabase db;
    late CliNote note;
    HttpServer? server;
    final key = Uint8List.fromList(List<int>.filled(32, 31));
    final errors = <Object>[];

    Future<void> credentials() async {
      final salt = List<int>.filled(32, 7);
      final machine = (await File('/etc/machine-id').readAsString()).trim();
      final storeKey = SecretKey(
        sha256.convert([
          ...salt,
          ...utf8.encode(machine),
          ...utf8.encode(Platform.environment['USER'] ?? ''),
        ]).bytes,
      );
      final entries = {
        'quietpaper_master_key_v1': base64Encode(key),
        'quietpaper_auth_session_v1': jsonEncode({
          'id': 'fixture-user',
          'idToken': 'fixture-token',
          'refreshToken': 'fixture-refresh',
          'tokenExpiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(days: 1))
              .toIso8601String(),
        }),
      };
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(entries)),
        secretKey: storeKey,
      );
      await File('${root.path}/.secure_storage_key').writeAsBytes(salt);
      await File(
        '${root.path}/.secure_storage_fallback.enc',
      ).writeAsBytes(box.concatenation());
    }

    Future<void> serve(
      Future<(int, Map<String, dynamic>)> Function(
        HttpRequest,
        Map<String, dynamic>,
      )
      handler, {
      bool wrongKey = false,
    }) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen((request) async {
        try {
          expect(
            request.headers.value('authorization'),
            'Bearer fixture-token',
          );
          expect(request.headers.value('x-device-id'), 'fixture-device');
          final text = await request
              .cast<List<int>>()
              .transform(utf8.decoder)
              .join();
          final body = text.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(text) as Map<String, dynamic>;
          final (status, value) = request.uri.path == '/api/v1/keys'
              ? (
                  200,
                  <String, dynamic>{
                    'keyAuthCommitment': wrongKey
                        ? 'wrong'
                        : sha256.convert(key).toString(),
                  },
                )
              : await handler(request, body);
          request.response.statusCode = status;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(value));
        } catch (error) {
          errors.add(error);
          request.response.statusCode = 500;
        } finally {
          await request.response.close();
        }
      });
    }

    Future<ProcessResult> run(List<String> arguments) => Process.run(
      binary!,
      ['--db', path, ...arguments],
      environment: {'QP_API_URL': 'http://127.0.0.1:${server!.port}'},
    );

    setUp(() async {
      root = await Directory.systemTemp.createTemp('qp-rust-sync-');
      path = '${root.path}/desktop.sqlite';
      final desktop = AppDatabase(NativeDatabase(File(path)));
      await desktop.customSelect('SELECT COUNT(*) FROM notes').get();
      await desktop.close();
      db = CliDatabase.open(path);
      note = db.createNote(
        title: 'Private title',
        content: 'Private body #tag',
      );
      db.connection.execute(
        "INSERT OR REPLACE INTO sync_metadata (key,value,updated_at) VALUES ('device_id','fixture-device',0),('cursor','42',0)",
      );
      await credentials();
      errors.clear();
    });
    tearDown(() async {
      await server?.close(force: true);
      server = null;
      db.close();
      await root.delete(recursive: true);
      expect(errors, isEmpty);
    });

    for (final mode in [
      'success',
      'http-failure',
      'conflict',
      'unacknowledged',
      'concurrent',
    ]) {
      test(
        'sync $mode preserves encrypted content and pending changes',
        () async {
          final source = NoteImportSource(
            fingerprint: 'fixture',
            importedAt: DateTime.utc(2026, 11, 25),
            subject: 'Private subject',
            sender: 'sender@example.org',
          );
          db.connection.execute(
            'UPDATE notes SET server_revision=3,pinned_tags=?,import_sources=? WHERE id=?',
            [
              '["tag"]',
              jsonEncode([source.toJson()]),
              note.id,
            ],
          );
          await serve((request, body) async {
            expect(request.uri.path, '/api/v1/sync/push');
            expect(jsonEncode(body), isNot(contains('Private body')));
            expect(jsonEncode(body), isNot(contains('Private subject')));
            final change = (body['changes'] as List).single as Map;
            expect(change['baseRevision'], 3);
            final plaintext = await DefaultCryptoService().decryptNote(
              envelope: EncryptedEnvelope(
                version: 1,
                algorithm: 'xchacha20-poly1305',
                keyVersion: 1,
                nonce: change['contentNonce'] as String,
                ciphertext: change['contentCiphertext'] as String,
              ),
              masterKeyBytes: key,
              noteId: note.id,
            );
            expect(plaintext.body, note.content);
            expect(plaintext.pinnedTags, ['tag']);
            expect(plaintext.importSources, [source]);
            if (mode == 'concurrent') {
              db.updateNote(
                id: note.id,
                title: note.title,
                content: 'New GUI edit',
              );
            }
            if (mode == 'http-failure') {
              return (503, <String, dynamic>{});
            }
            if (mode == 'conflict') {
              return (
                200,
                {
                  'conflicts': [
                    {'id': note.id},
                  ],
                  'results': [],
                },
              );
            }
            return (
              200,
              {
                'conflicts': [],
                'results': mode == 'unacknowledged'
                    ? []
                    : [
                        {'id': note.id, 'revision': 4},
                      ],
              },
            );
          });
          final before = await File(
            '${root.path}/.secure_storage_fallback.enc',
          ).readAsBytes();
          final result = await run(['sync', note.id]);
          expect(
            result.exitCode,
            mode == 'success' ? 0 : 1,
            reason: '${result.stdout}\n${result.stderr}',
          );
          final row = db.connection.select('SELECT * FROM notes WHERE id=?', [
            note.id,
          ]).single;
          expect(row['is_dirty'], mode == 'success' ? 0 : 1);
          expect(
            row['content'],
            mode == 'concurrent' ? 'New GUI edit' : note.content,
          );
          expect(
            db.connection.select('SELECT * FROM sync_queue WHERE note_id=?', [
              note.id,
            ]).isEmpty,
            mode == 'success',
          );
          expect(
            db.connection
                .select("SELECT value FROM sync_metadata WHERE key='cursor'")
                .single['value'],
            '42',
          );
          expect(
            await File(
              '${root.path}/.secure_storage_fallback.enc',
            ).readAsBytes(),
            before,
          );
        },
      );
    }

    test(
      'failed references replay the exact encrypted push and idempotency key',
      () async {
        const resource = '11111111-2222-4333-8444-555555555555';
        note = db.updateNote(
          id: note.id,
          title: note.title,
          content: 'Private document qp://document/$resource',
        );
        final pushes = <Map<String, dynamic>>[];
        var fail = true;
        await serve((request, body) async {
          if (request.uri.path == '/api/v1/sync/push') {
            pushes.add(body);
            return (
              200,
              {
                'results': [
                  {'id': note.id, 'revision': 5},
                ],
                'conflicts': [],
              },
            );
          }
          expect(request.uri.path, '/api/v1/sync/references');
          expect((body['references'] as List).single, {
            'resourceType': 'document',
            'resourceId': resource,
            'noteId': note.id,
          });
          return (fail ? 503 : 200, {'success': !fail});
        });
        final failed = await run(['sync', note.id]);
        expect(failed.exitCode, 1);
        expect(
          db.connection
              .select('SELECT server_revision,is_dirty FROM notes')
              .single['server_revision'],
          5,
        );
        expect(
          db.connection.select(
            "SELECT * FROM sync_metadata WHERE key LIKE 'cli_push:%'",
          ),
          hasLength(1),
        );
        fail = false;
        final retry = await run(['sync', note.id]);
        expect(retry.exitCode, 0, reason: retry.stderr.toString());
        expect(pushes, hasLength(2));
        expect(pushes[1], pushes[0]);
        expect(
          db.connection.select('SELECT is_dirty FROM notes').single['is_dirty'],
          0,
        );
        expect(
          db.connection.select(
            "SELECT * FROM sync_metadata WHERE key LIKE 'cli_push:%'",
          ),
          isEmpty,
        );
      },
    );

    test('key mismatch prevents any encrypted note or image upload', () async {
      var calls = 0;
      await serve((request, body) async {
        calls++;
        return (500, <String, dynamic>{});
      }, wrongKey: true);
      final result = await run(['sync']);
      expect(result.exitCode, 1);
      expect(calls, 0);
      expect(db.getNoteByIdOrPrefix(note.id)!.content, note.content);
      expect(
        db.connection.select('SELECT is_dirty FROM notes').single['is_dirty'],
        1,
      );
    });

    test(
      'permanent delete sends a revision-bound tombstone and retains no queue after ack',
      () async {
        db.connection.execute('UPDATE notes SET server_revision=8 WHERE id=?', [
          note.id,
        ]);
        await serve((request, body) async {
          expect(request.uri.path, '/api/v1/sync/push');
          final change = (body['changes'] as List).single as Map;
          expect(change['id'], note.id);
          expect(change['baseRevision'], 8);
          expect(change['isDeleted'], true);
          expect(change['contentCiphertext'], '');
          return (
            200,
            {
              'results': [
                {'id': note.id, 'revision': 9},
              ],
              'conflicts': [],
            },
          );
        });
        final result = await run(['delete', note.id, '--permanent']);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(db.getNoteByIdOrPrefix(note.id), isNull);
        expect(db.connection.select('SELECT * FROM sync_queue'), isEmpty);
        expect(
          db.connection.select(
            "SELECT * FROM sync_metadata WHERE key LIKE 'cli_delete:%'",
          ),
          isEmpty,
        );
      },
    );

    test(
      'sync discovers pending images on clean notes and rejects non-HTTPS upload URLs',
      () async {
        const image = '11111111-2222-4333-8444-555555555555';
        db.connection.execute(
          'UPDATE notes SET content=?,is_dirty=0 WHERE id=?',
          ['![image](qp://asset/$image)', note.id],
        );
        final encrypted = await AttachmentCrypto().encryptAttachment(
          plaintextBytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          masterKeyBytes: key,
          attachmentId: image,
        );
        final file = File('${root.path}/image.enc');
        await file.writeAsBytes(encrypted);
        db.connection.execute(
          "INSERT INTO attachments (id,note_id,created_at,updated_at,local_path,byte_size,sha256,is_dirty,upload_state) VALUES (?,?,0,0,?,8,?,1,'upload_pending')",
          [
            image,
            note.id,
            file.path,
            sha256.convert([137, 80, 78, 71, 13, 10, 26, 10]).toString(),
          ],
        );
        var uploadAuth = false;
        await serve((request, body) async {
          expect(request.uri.path, '/api/v1/attachments/upload-auth');
          uploadAuth = true;
          return (200, {'uploadUrl': 'http://127.0.0.1:1/upload'});
        });
        final result = await run(['sync']);
        expect(result.exitCode, 1);
        expect(uploadAuth, true);
        expect(result.stderr, contains('HTTPS'));
        expect(
          db.connection
              .select('SELECT is_dirty FROM attachments')
              .single['is_dirty'],
          1,
        );
      },
    );
  }, skip: binary == null ? 'Enable with scripts/test_rust_cli.sh' : false);
}
