import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

// The dedicated Rust CLI gate builds the binary and enables these cross-language
// tests. Ordinary Flutter-only runs do not require a Rust toolchain.
void main() {
  final binary = Platform.environment['QP_RUST_CLI_BIN'];

  group('Rust CLI with the actual desktop Drift schema', () {
    late Directory root;
    late String path;
    late CliDatabase dartCli;
    late AppDatabase desktop;
    late CliNote active;
    late CliNote archived;

    Future<ProcessResult> run(List<String> arguments) =>
        Process.run(binary!, ['--db', path, ...arguments]);

    Future<dynamic> jsonResult(List<String> arguments) async {
      final result = await run([...arguments, '--json']);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stderr, isEmpty);
      return jsonDecode(result.stdout as String);
    }

    setUp(() async {
      expect(File(binary!).existsSync(), isTrue);
      root = Directory.systemTemp.createTempSync('qp_rust_compat_');
      path = '${root.path}/desktop.sqlite';
      final initial = AppDatabase(NativeDatabase(File(path)));
      await initial.customSelect('SELECT COUNT(*) FROM notes').get();
      await initial.close();

      dartCli = CliDatabase.open(path);
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
  }, skip: binary == null ? 'Enable with scripts/test_rust_cli.sh' : false);
}
