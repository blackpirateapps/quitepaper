import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/note_version_model.dart';

void main() {
  group('NoteVersion Model', () {
    test('countWords accurately calculates word counts', () {
      expect(NoteVersion.countWords(''), equals(0));
      expect(NoteVersion.countWords('   '), equals(0));
      expect(NoteVersion.countWords('Hello world'), equals(2));
      expect(NoteVersion.countWords('Hello   \n  world \t test'), equals(3));
    });

    test('computeDeltaSummary formats word deltas', () {
      expect(
        NoteVersion.computeDeltaSummary(
          oldContent: 'one two three',
          newContent: 'one two three four five six seven',
          oldTitle: 'Title',
          newTitle: 'Title',
          oldTags: [],
          newTags: [],
        ),
        equals('+4 words'),
      );
      expect(
        NoteVersion.computeDeltaSummary(
          oldContent: 'one two three four five',
          newContent: 'one two',
          oldTitle: 'Title',
          newTitle: 'Title',
          oldTags: [],
          newTags: [],
        ),
        equals('-3 words'),
      );
      expect(
        NoteVersion.computeDeltaSummary(
          oldContent: 'one two three',
          newContent: 'one two three',
          oldTitle: 'Title',
          newTitle: 'Title',
          oldTags: [],
          newTags: [],
        ),
        equals('Content edited'),
      );
    });

    test('json serialization and deserialization preserves all fields', () {
      final now = DateTime.now();
      final version = NoteVersion(
        id: 'v-1',
        noteId: 'note-100',
        versionNumber: 3,
        title: 'Meeting Notes',
        content: '# Agenda\n- Discussion items',
        tags: ['meeting', 'team'],
        createdAt: now,
        charCount: 27,
        wordCount: 4,
        deltaSummary: '+4 words',
        serverRevision: 2,
        isDirty: false,
        syncedAt: now,
      );

      final json = version.toJson();
      final fromJson = NoteVersion.fromJson(json);

      expect(fromJson.id, equals(version.id));
      expect(fromJson.noteId, equals(version.noteId));
      expect(fromJson.versionNumber, equals(3));
      expect(fromJson.title, equals('Meeting Notes'));
      expect(fromJson.content, equals('# Agenda\n- Discussion items'));
      expect(fromJson.tags, equals(['meeting', 'team']));
      expect(fromJson.charCount, equals(27));
      expect(fromJson.wordCount, equals(4));
      expect(fromJson.deltaSummary, equals('+4 words'));
      expect(fromJson.serverRevision, equals(2));
      expect(fromJson.isDirty, isFalse);
    });
  });
}
