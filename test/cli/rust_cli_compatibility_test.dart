import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
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
  }, skip: binary == null ? 'Enable with scripts/test_rust_cli.sh' : false);
}
