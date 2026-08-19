import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/version_session_tracker.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('VersionSessionTracker', () {
    late Note initialNote;
    late VersionSessionTracker tracker;

    setUp(() {
      initialNote = Note(
        id: 'test-note-1',
        title: 'Initial Title',
        content: 'This is the initial content of the note.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['work', 'project'],
      );
      tracker = VersionSessionTracker(initialNote);
    });

    test('no change is not a meaningful session', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Initial Title',
          finalContent: 'This is the initial content of the note.',
          finalTags: ['work', 'project'],
        ),
        isFalse,
      );
    });

    test('micro edit with few characters is filtered out', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Initial Title',
          finalContent: 'This is the initial content of the note..',
          finalTags: ['work', 'project'],
        ),
        isFalse,
      );
    });

    test('title change is always a meaningful session', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Updated Title',
          finalContent: 'This is the initial content of the note.',
          finalTags: ['work', 'project'],
        ),
        isTrue,
      );
    });

    test('tag addition or removal is always a meaningful session', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Initial Title',
          finalContent: 'This is the initial content of the note.',
          finalTags: ['work'],
        ),
        isTrue,
      );
    });

    test('structural markdown change is a meaningful session', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Initial Title',
          finalContent: 'This is the initial content of the note.\n- [ ] Task',
          finalTags: ['work', 'project'],
        ),
        isTrue,
      );
    });

    test('substantive text addition is a meaningful session', () {
      expect(
        tracker.isMeaningfulSession(
          finalTitle: 'Initial Title',
          finalContent: 'This is the initial content of the note. Adding a completely new paragraph with lots of words.',
          finalTags: ['work', 'project'],
        ),
        isTrue,
      );
    });

    test('generates helpful delta summaries', () {
      final summary = tracker.generateSummary(
        finalTitle: 'New Title',
        finalContent: 'This is the initial content of the note.\n- [ ] Task 1',
        finalTags: ['work', 'urgent'],
      );
      expect(summary, isNotEmpty);
    });
  });
}
