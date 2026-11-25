import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'support/desktop_notebook_fixture.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';

// The dedicated Rust CLI gate builds the binary and enables these cross-language
// tests. Ordinary Flutter-only runs do not require a Rust toolchain.
void main() {
  final binary = Platform.environment['QP_RUST_CLI_BIN'];

  group('Rust CLI with the actual desktop Drift schema', () {
    late Directory root;
    late String path;
    late DesktopNotebookFixture dartCli;
    late AppDatabase desktop;
    late FixtureNote active;
    late FixtureNote archived;

    Future<ProcessResult> run(List<String> arguments) =>
        Process.run(binary!, ['--db', path, ...arguments]);

    Future<dynamic> jsonResult(List<String> arguments) async {
      final result = await run([...arguments, '--json']);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr, isEmpty);
      return jsonDecode(result.stdout as String);
    }

    Future<ProcessResult> create(
      String content, [
      List<String> options = const [],
    ]) async {
      final process = await Process.start(binary!, [
        '--db',
        path,
        'new',
        ...options,
      ]);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(content);
      await process.stdin.close();
      return ProcessResult(
        process.pid,
        await process.exitCode,
        await output,
        await errors,
      );
    }

    final testKey = Uint8List.fromList(List<int>.filled(32, 23));
    Future<void> storeCredentials(Map<String, String> entries) async {
      final salt = List<int>.filled(32, 7);
      final machine = (await File('/etc/machine-id').readAsString()).trim();
      final key = SecretKey(
        sha256.convert([
          ...salt,
          ...utf8.encode(machine),
          ...utf8.encode(Platform.environment['USER'] ?? ''),
        ]).bytes,
      );
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode(entries)),
        secretKey: key,
      );
      await File('${root.path}/.secure_storage_key').writeAsBytes(salt);
      await File(
        '${root.path}/.secure_storage_fallback.enc',
      ).writeAsBytes(box.concatenation());
    }

    Future<File> photo([String name = 'photo with spaces.png']) async {
      final file = File('${root.path}/$name');
      await file.writeAsBytes(img.encodePng(img.Image(width: 4, height: 3)));
      return file;
    }

    Future<List<dynamic>> imageRows(String noteId) async =>
        await jsonResult(['attachments', noteId]) as List<dynamic>;

    setUp(() async {
      expect(File(binary!).existsSync(), isTrue);
      root = Directory.systemTemp.createTempSync('qp_rust_compat_');
      path = '${root.path}/desktop.sqlite';
      final initial = AppDatabase(NativeDatabase(File(path)));
      await initial.customSelect('SELECT COUNT(*) FROM notes').get();
      await initial.close();

      dartCli = DesktopNotebookFixture.open(path);
      active = dartCli.createNote(
        title: 'বাংলা Journal',
        content:
            '---\r\ntitle: বাংলা Journal\r\n---\r\n'
            '# Heading\r\nBody with #work/cli and #shared.\r\n',
        isPinned: true,
      );
      archived = dartCli.createNote(
        title: 'Archived',
        content: 'Old #shared entry',
      );
      final trashed = dartCli.createNote(
        title: 'Trash',
        content: 'Trashed #shared entry',
      );
      dartCli.connection.execute(
        'UPDATE notes SET is_archived = 1 WHERE id = ?',
        [archived.id],
      );
      dartCli.trashNote(trashed.id);
      // Compare persisted timestamps, not the unrounded in-memory create result.
      active = dartCli.getNoteByIdOrPrefix(active.id)!;
      desktop = AppDatabase(NativeDatabase(File(path)));
      await desktop.customSelect('SELECT COUNT(*) FROM notes').get();
    });

    tearDown(() async {
      await desktop.close();
      dartCli.close();
      root.deleteSync(recursive: true);
    });

    test('list JSON and filters match Dart on schema 25', () async {
      expect(await jsonResult(['list']), [active.toJson()]);
      expect(await jsonResult(['list', '--tag', '#WORK']), [active.toJson()]);
      expect(await jsonResult(['list', '--search', 'Body']), [active.toJson()]);
      expect(await jsonResult(['list', '--archived']), [
        dartCli.getNoteByIdOrPrefix(archived.id)!.toJson(),
      ]);
      expect(
        await jsonResult(['list', '--trash']),
        dartCli
            .listNotes(showTrash: true)
            .map((note) => note.toJson())
            .toList(),
      );
      final version = await desktop
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), desktop.schemaVersion);
    });

    test(
      'show preserves CRLF and reports current committed WAL data',
      () async {
        final result = await run(['show', active.shortId, '--raw']);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout, active.content);
        expect(await jsonResult(['show', active.id]), active.toJson());
        await desktop.customStatement(
          'UPDATE notes SET title = ? WHERE id = ?',
          ['Changed from desktop', active.id],
        );
        final note =
            await jsonResult(['show', active.id]) as Map<String, dynamic>;
        expect(note['title'], 'Changed from desktop');
      },
    );

    test(
      'tags count active notes; reads retain schema, queues and stored titles',
      () async {
        // Deliberately bypass the Dart opener's title repair. Rust must only clean
        // this value for display, never modify the stored row or dirty/sync state.
        dartCli.connection.execute('UPDATE notes SET title = ? WHERE id = ?', [
          'title: "Display only"',
          active.id,
        ]);
        final before = jsonEncode(
          dartCli.connection.select('SELECT * FROM notes ORDER BY id'),
        );
        final queueBefore = jsonEncode(
          dartCli.connection.select('SELECT * FROM sync_queue ORDER BY id'),
        );
        final schemaBefore = jsonEncode(
          dartCli.connection.select(
            'SELECT * FROM sqlite_master ORDER BY name',
          ),
        );
        final tags = await jsonResult(['tags']) as List<dynamic>;
        expect(tags.map((tag) => tag['name']), ['shared', 'work/cli']);
        expect(tags.map((tag) => tag['noteCount']), [1, 1]);
        final note =
            await jsonResult(['show', active.id]) as Map<String, dynamic>;
        expect(note['title'], 'Display only');
        await jsonResult(['list']);
        expect(
          jsonEncode(
            dartCli.connection.select('SELECT * FROM notes ORDER BY id'),
          ),
          before,
        );
        expect(
          jsonEncode(
            dartCli.connection.select('SELECT * FROM sync_queue ORDER BY id'),
          ),
          queueBefore,
        );
        expect(
          jsonEncode(
            dartCli.connection.select(
              'SELECT * FROM sqlite_master ORDER BY name',
            ),
          ),
          schemaBefore,
        );
        // A separate read-only connection confirms this is an ordinary SQLite
        // notebook that remains accessible independently of either CLI runtime.
        final verifier = sqlite3.open(path, mode: OpenMode.readOnly);
        try {
          expect(
            verifier.select('PRAGMA user_version').single['user_version'],
            25,
          );
        } finally {
          verifier.close();
        }
      },
    );

    test(
      'Rust create persists desktop-readable tags, history, queue and FTS',
      () async {
        final result = await create(
          '---\ntitle: Rust Journal\njournal: true\ndate: 2026-11-25\ntags: [journal/2026]\n---\nBody #বাংলা `#hidden`',
          ['--tag', 'work/cli', '--pinned'],
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final rows = await desktop
            .customSelect("SELECT * FROM notes WHERE title='Rust Journal'")
            .get();
        expect(rows, hasLength(1));
        final id = rows.single.read<String>('id');
        expect(rows.single.read<int>('is_pinned'), 1);
        expect(rows.single.read<String>('journal_date'), '2026-11-25');
        expect(dartCli.findNotesByTitle('Rust Journal').single.tags, [
          'journal/2026',
          'work/cli',
          'বাংলা',
        ]);
        expect(
          (await desktop
              .customSelect(
                'SELECT * FROM note_versions WHERE note_id=?',
                variables: [Variable(id)],
              )
              .get()),
          hasLength(1),
        );
        expect(
          dartCli.connection.select(
            'SELECT * FROM sync_queue WHERE note_id=?',
            [id],
          ),
          hasLength(1),
        );
        expect(
          dartCli.connection.select(
            "SELECT note_id FROM note_search_prefix WHERE note_search_prefix MATCH 'Rust' AND note_id=?",
            [id],
          ),
          hasLength(1),
        );
        expect(
          dartCli.connection
              .select('PRAGMA user_version')
              .single['user_version'],
          25,
        );
      },
    );

    test('Rust editor updates preserve desktop fields and per-tag pins', () async {
      dartCli.connection.execute(
        'UPDATE notes SET pinned_tags=?, import_sources=?, server_revision=17, share_id=? WHERE id=?',
        ['["shared"]', '[]', 'keep-share', active.id],
      );
      final script = File('${root.path}/editor with spaces.sh');
      script.writeAsStringSync(
        'printf \'# Edited from Rust\\n\\nChanged #shared #work/cli\\n\' > "\$1"\n',
      );
      final result = await run([
        'edit',
        active.id,
        '--editor',
        'sh ${jsonEncode(script.path)}',
        '--no-pinned',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final updated = dartCli.getNoteByIdOrPrefix(active.id)!;
      expect(updated.title, 'Edited from Rust');
      expect(updated.isPinned, isFalse);
      final row = dartCli.connection.select('SELECT * FROM notes WHERE id=?', [
        active.id,
      ]).single;
      expect(row['share_id'], 'keep-share');
      expect(row['server_revision'], 17);
      expect(row['pinned_tags'], '["shared"]');
      expect(
        dartCli.connection.select(
          'SELECT nt.is_pinned FROM note_tags nt JOIN tags t ON t.id=nt.tag_id WHERE nt.note_id=? AND t.name=?',
          [active.id, 'shared'],
        ).single['is_pinned'],
        1,
      );
      expect(
        dartCli.connection.select(
          'SELECT * FROM note_versions WHERE note_id=?',
          [active.id],
        ),
        hasLength(2),
      );
    });

    test(
      'Rust trash restore and permanent deletion maintain FTS and tombstone',
      () async {
        for (final flags in [
          <String>[],
          ['--restore'],
        ]) {
          final result = await run(['delete', active.id, ...flags]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            dartCli.getNoteByIdOrPrefix(active.id)!.isTrashed,
            flags.isEmpty,
          );
          expect(
            dartCli.connection.select(
              'SELECT * FROM note_search_prefix WHERE note_id=?',
              [active.id],
            ),
            hasLength(flags.isEmpty ? 0 : 1),
          );
        }
        final result = await run(['delete', active.id, '--permanent']);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(dartCli.getNoteByIdOrPrefix(active.id), isNull);
        expect(
          dartCli.connection.select('SELECT * FROM note_tags WHERE note_id=?', [
            active.id,
          ]),
          isEmpty,
        );
        expect(
          dartCli.connection.select(
            'SELECT * FROM note_versions WHERE note_id=?',
            [active.id],
          ),
          isEmpty,
        );
        expect(
          dartCli.connection.select(
            "SELECT * FROM sync_queue WHERE note_id=? AND operation='delete'",
            [active.id],
          ),
          hasLength(1),
        );
      },
    );

    test(
      'write failure rolls back all rows and preserves a private draft',
      () async {
        final before = jsonEncode(
          dartCli.connection.select('SELECT * FROM notes ORDER BY id'),
        );
        final queue = dartCli.connection
            .select('SELECT COUNT(*) AS n FROM sync_queue')
            .single['n'];
        dartCli.connection.execute(
          "CREATE TRIGGER reject_rust_history BEFORE INSERT ON note_versions BEGIN SELECT RAISE(ABORT,'injected history failure'); END",
        );
        final result = await create('# Must roll back\n#newtag');
        expect(result.exitCode, 1);
        expect(
          jsonEncode(
            dartCli.connection.select('SELECT * FROM notes ORDER BY id'),
          ),
          before,
        );
        expect(
          dartCli.connection
              .select('SELECT COUNT(*) AS n FROM sync_queue')
              .single['n'],
          queue,
        );
        expect(
          dartCli.connection.select("SELECT * FROM tags WHERE name='newtag'"),
          isEmpty,
        );
        final draft = Directory(
          '${root.path}/cli-drafts',
        ).listSync().whereType<File>().single;
        expect(draft.readAsStringSync(), '# Must roll back\n#newtag');
        expect(draft.statSync().mode & 0x1ff, 0x180);
      },
    );

    test(
      'concurrent edit refuses overwrite and retains original edited draft',
      () async {
        final script = File('${root.path}/race.py');
        script.writeAsStringSync(
          'import sqlite3, sys\n'
          'db=sqlite3.connect(${jsonEncode(path)})\n'
          'db.execute("UPDATE notes SET content=? WHERE id=?", ("Changed in desktop", ${jsonEncode(active.id)}))\n'
          'db.commit()\n'
          'open(sys.argv[1], "w").write("# Editor draft\\nDo not lose this")\n',
        );
        final result = await run([
          'edit',
          active.id,
          '--editor',
          'python3 ${jsonEncode(script.path)}',
        ]);
        expect(result.exitCode, 1);
        expect(
          dartCli.getNoteByIdOrPrefix(active.id)!.content,
          'Changed in desktop',
        );
        final draft = Directory(
          '${root.path}/cli-drafts',
        ).listSync().whereType<File>().single;
        expect(draft.readAsStringSync(), '# Editor draft\nDo not lose this');
      },
    );
    test(
      'Rust imports deduplicate Markdown images and Dart decrypts QPA1 bytes',
      () async {
        await storeCredentials({
          'quietpaper_master_key_v1': base64Encode(testKey),
        });
        final file = await photo();
        final original = await file.readAsBytes();
        final credentialFile = File(
          '${root.path}/.secure_storage_fallback.enc',
        );
        final before = await credentialFile.readAsBytes();
        const content =
            '# Rust Images\n![first](<photo with spaces.png>)\n![second][image]\n\n[image]: <photo with spaces.png>\n`![example](missing.png)`\n![remote](https://example.org/remote.png)\n';
        final result = await create(content, [
          '--base-dir',
          root.path,
          '--attach',
          file.path,
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final note = dartCli.findNotesByTitle('Rust Images').single;
        final rows = await imageRows(note.id);
        expect(rows, hasLength(1));
        final row = rows.single as Map;
        expect(note.content, contains('`![example](missing.png)`'));
        expect(
          note.content,
          contains('![remote](https://example.org/remote.png)'),
        );
        expect('qp://asset/'.allMatches(note.content), hasLength(3));
        expect(row['upload_state'], 'upload_pending');
        expect(row['ocr_state'], 'queued');
        final encrypted = File(row['local_path'] as String);
        final decrypted = await AttachmentCrypto().decryptAttachment(
          encryptedEnvelopeBytes: await encrypted.readAsBytes(),
          masterKeyBytes: testKey,
          attachmentId: row['id'] as String,
        );
        expect(decrypted, original);
        expect(encrypted.statSync().mode & 0x1ff, 0x180);
        expect(await credentialFile.readAsBytes(), before);
        expect(await file.readAsBytes(), original);
        final attachment = await desktop.getAttachment(row['id'] as String);
        expect(attachment!.fileName, 'photo with spaces.png');
        expect(attachment.byteSize, original.length);
      },
    );

    test(
      'Rust attachment transaction failure removes staged ciphertext and rolls back note',
      () async {
        await storeCredentials({
          'quietpaper_master_key_v1': base64Encode(testKey),
        });
        final file = await photo();
        dartCli.connection.execute(
          "CREATE TRIGGER reject_image BEFORE INSERT ON attachments BEGIN SELECT RAISE(ABORT,'injected image failure'); END",
        );
        final result = await create(
          '# Failed image\n![local](<photo with spaces.png>)',
          ['--base-dir', root.path],
        );
        expect(result.exitCode, 1);
        expect(dartCli.findNotesByTitle('Failed image'), isEmpty);
        expect(dartCli.connection.select('SELECT * FROM attachments'), isEmpty);
        expect(Directory('${root.path}/attachments').listSync(), isEmpty);
        final draft = Directory(
          '${root.path}/cli-drafts',
        ).listSync().whereType<File>().single;
        expect(
          draft.readAsStringSync(),
          '# Failed image\n![local](<photo with spaces.png>)',
        );
        expect(await file.exists(), isTrue);
      },
    );

    test(
      'Rust explicit attach compresses still images and rejects damaged files',
      () async {
        await storeCredentials({
          'quietpaper_master_key_v1': base64Encode(testKey),
        });
        final file = await photo();
        final result = await run([
          'attach',
          active.id,
          file.path,
          '--compress',
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final row = (await imageRows(active.id)).single as Map;
        expect(row['mime_type'], 'image/jpeg');
        final bytes = await AttachmentCrypto().decryptAttachment(
          encryptedEnvelopeBytes: await File(
            row['local_path'] as String,
          ).readAsBytes(),
          masterKeyBytes: testKey,
          attachmentId: row['id'] as String,
        );
        expect(img.decodeJpg(bytes)!.width, 4);
        final bad = File('${root.path}/bad.png')..writeAsStringSync('invalid');
        final failed = await run(['attach', active.id, bad.path]);
        expect(failed.exitCode, 1);
        expect(await imageRows(active.id), hasLength(1));
      },
    );

    test(
      'wrapped credentials fail clearly in scripts without modifying the notebook',
      () async {
        final crypto = DefaultCryptoService();
        const params = KdfParameters(memory: 32, iterations: 1);
        final salt = Uint8List.fromList(List<int>.filled(16, 4));
        final wrapping = await crypto.deriveKeyFromPassword(
          password: 'correct',
          salt: salt,
          parameters: params,
        );
        final envelope = await crypto.wrapMasterKey(
          masterKeyBytes: testKey,
          wrappingKey: wrapping,
        );
        final wrapped = WrappedMasterKeyData(
          keyVersion: 1,
          wrappedMasterKey: envelope.ciphertext,
          wrappedNonce: envelope.nonce,
          kdfAlgorithm: 'argon2id',
          kdfSalt: base64Encode(salt),
          kdfParameters: params,
          encryptionFormatVersion: 1,
        );
        await storeCredentials({
          'quietpaper_wrapped_master_key_v1': jsonEncode(wrapped.toJson()),
        });
        final file = await photo();
        final failed = await run(['attach', active.id, file.path]);
        expect(failed.exitCode, 1);
        expect(failed.stderr, contains('Run interactively'));
        expect(await imageRows(active.id), isEmpty);
        // A real controlling terminal exercises the same Argon2id and key-wrap
        // formats generated by Dart, without introducing a password CLI option.
        final script = File('${root.path}/terminal.py');
        script.writeAsStringSync(r'''
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], [sys.argv[1], '--db', sys.argv[2], 'attach', sys.argv[3], sys.argv[4]])
data = b''
sent = False
end = time.monotonic() + 15
while time.monotonic() < end:
    ready, _, _ = select.select([fd], [], [], 0.1)
    if ready:
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        data += chunk
        if b'Encryption password:' in data and not sent:
            os.write(fd, sys.argv[5].encode() + b'\n')
            sent = True
else:
    os.kill(pid, 9)
_, status = os.waitpid(pid, 0)
sys.stdout.buffer.write(data)
sys.exit(os.waitstatus_to_exitcode(status))
''');
        final wrong = await Process.run('python3', [
          script.path,
          binary!,
          path,
          active.id,
          file.path,
          'wrong',
        ]);
        expect(wrong.exitCode, 1);
        expect(await imageRows(active.id), isEmpty);
        final interactive = await Process.run('python3', [
          script.path,
          binary,
          path,
          active.id,
          file.path,
          'correct',
        ]);
        expect(
          interactive.exitCode,
          0,
          reason: '${interactive.stdout}\n${interactive.stderr}',
        );
        final row = (await imageRows(active.id)).single as Map;
        final bytes = await AttachmentCrypto().decryptAttachment(
          encryptedEnvelopeBytes: await File(
            row['local_path'] as String,
          ).readAsBytes(),
          masterKeyBytes: testKey,
          attachmentId: row['id'] as String,
        );
        expect(bytes, await file.readAsBytes());
      },
    );
    test(
      'Rust clipboard import uses bounded helper output and open refuses scripts',
      () async {
        await storeCredentials({
          'quietpaper_master_key_v1': base64Encode(testKey),
        });
        final file = await photo();
        final helpers = Directory('${root.path}/helpers')..createSync();
        final helper = File('${helpers.path}/wl-paste')
          ..writeAsStringSync('#!/bin/sh\ncat ${jsonEncode(file.path)}\n');
        expect((await Process.run('chmod', ['700', helper.path])).exitCode, 0);
        final result = await Process.run(
          binary!,
          ['--db', path, 'attach', active.id, '--clipboard'],
          environment: {
            'PATH': '${helpers.path}:${Platform.environment['PATH']}',
            'WAYLAND_DISPLAY': 'test',
          },
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final row = (await imageRows(active.id)).single as Map;
        expect(row['file_name'], 'clipboard.png');
        final open = await run([
          'attachments',
          active.id,
          'open',
          row['id'] as String,
        ]);
        expect(open.exitCode, 1);
        expect(open.stderr, contains('interactive terminal'));
      },
    );
    test(
      'Rust new bootstraps a private notebook that the desktop opens without migration',
      () async {
        final fresh = '${root.path}/fresh/notebook.sqlite';
        Future<void> write(String title) async {
          final process = await Process.start(binary!, ['--db', fresh, 'new']);
          final output = process.stdout.transform(utf8.decoder).join();
          final errors = process.stderr.transform(utf8.decoder).join();
          process.stdin.write('# $title\n\n#fresh');
          await process.stdin.close();
          expect(
            await process.exitCode,
            0,
            reason: '${await output}\n${await errors}',
          );
        }

        await Future.wait([
          write('First CLI notebook'),
          write('Second CLI notebook'),
        ]);
        expect(File(fresh).statSync().mode & 0x1ff, 0x180);
        await desktop.close();
        desktop = AppDatabase(NativeDatabase(File(fresh)));
        final rows = await desktop.customSelect('SELECT * FROM notes').get();
        expect(rows.map((row) => row.read<String>('title')).toSet(), {
          'First CLI notebook',
          'Second CLI notebook',
        });
        expect(
          (await desktop.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          25,
        );
        expect(
          await desktop.customSelect('SELECT * FROM watched_folders').get(),
          isEmpty,
        );
      },
    );
    test(
      'pin-only changes retain stored titles and manual desktop tags',
      () async {
        dartCli.connection.execute(
          'UPDATE notes SET title=?,content=? WHERE id=?',
          ['GUI-selected title', '# Different heading\n#shared', active.id],
        );
        final result = await run([
          'edit',
          active.id,
          '--editor',
          'true',
          '--no-pinned',
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final current = dartCli.getNoteByIdOrPrefix(active.id)!;
        expect(current.title, 'GUI-selected title');
        expect(current.content, '# Different heading\n#shared');
        expect(current.tags, ['shared', 'work/cli']);
        expect(current.isPinned, false);
      },
    );
  }, skip: binary == null ? 'Enable with scripts/test_rust_cli.sh' : false);
}
