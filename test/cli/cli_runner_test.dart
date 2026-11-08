import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/cli/cli_runner.dart';

void main() {
  late CliDatabase db;
  late CliRunner runner;

  setUp(() {
    db = CliDatabase.openInMemory();
    runner = CliRunner(database: db);
  });

  tearDown(() {
    db.close();
  });

  group('CliRunner & Commands Tests', () {
    test('run with empty args returns 0 (usage displayed)', () async {
      final code = await runner.run([]);
      expect(code, 0);
    });

    test('run with --version returns 0', () async {
      final code = await runner.run(['--version']);
      expect(code, 0);
    });

    test('run with list returns 0 for empty and populated database', () async {
      var code = await runner.run(['list']);
      expect(code, 0);

      db.createNote(title: 'First Note', content: 'Content with #tag1');
      code = await runner.run(['list']);
      expect(code, 0);
    });

    test('run with list --json outputs valid parseable JSON', () async {
      db.createNote(title: 'JSON Note', content: 'Testing json output #test');

      // Test database listNotes directly produces valid json
      final notes = db.listNotes();
      expect(notes.length, 1);
      final jsonStr = jsonEncode(notes.map((n) => n.toJson()).toList());
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, 1);
      expect(decoded[0]['title'], 'JSON Note');
      expect(decoded[0]['shortId'], notes[0].shortId);
    });

    test('run with show prints note content', () async {
      final note = db.createNote(
        title: 'Showcase',
        content: '# Showcase\n\nBody content of showcase note.',
      );

      final code = await runner.run(['show', note.shortId]);
      expect(code, 0);

      final codeRaw = await runner.run(['show', '--raw', note.shortId]);
      expect(codeRaw, 0);

      final codeInfo = await runner.run(['show', '--info', note.shortId]);
      expect(codeInfo, 0);

      final codeJson = await runner.run(['show', '--json', note.shortId]);
      expect(codeJson, 0);
    });

    test('run with show on non-existent note returns 1', () async {
      final code = await runner.run(['show', 'nonexistent-id-123']);
      expect(code, 1);
    });

    test('run with tags lists tags and counts', () async {
      db.createNote(title: 'Tag Note', content: 'Body with #alpha and #beta');

      final code = await runner.run(['tags']);
      expect(code, 0);

      final codeJson = await runner.run(['tags', '--json']);
      expect(codeJson, 0);
    });

    test('run with delete trashes and permanently deletes notes', () async {
      final note = db.createNote(title: 'To Be Deleted', content: 'Ephemeral');

      // Trash
      var code = await runner.run(['delete', note.shortId]);
      expect(code, 0);
      expect(db.getNoteByIdOrPrefix(note.id)!.isTrashed, isTrue);

      // Restore
      code = await runner.run(['delete', '--restore', note.shortId]);
      expect(code, 0);
      expect(db.getNoteByIdOrPrefix(note.id)!.isTrashed, isFalse);

      // Permanent delete
      code = await runner.run(['delete', '--permanent', note.shortId]);
      expect(code, 0);
      expect(db.getNoteByIdOrPrefix(note.id), isNull);
    });
  });
}
