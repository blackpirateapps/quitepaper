import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/date_formatter.dart';
import 'package:quitepaper/features/notes/domain/note_group.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('DateFormatter & NoteGroup Tests', () {
    final now = DateTime(2026, 8, 18, 14, 30); // Tuesday

    test('getGroupBucket returns expected buckets', () {
      // Today
      expect(
        DateFormatter.getGroupBucket(DateTime(2026, 8, 18, 9, 0), now: now),
        'Today',
      );

      // Yesterday
      expect(
        DateFormatter.getGroupBucket(DateTime(2026, 8, 17, 20, 0), now: now),
        'Yesterday',
      );

      // 2 days ago (Sunday)
      expect(
        DateFormatter.getGroupBucket(DateTime(2026, 8, 16, 12, 0), now: now),
        'Sunday',
      );

      // 8 days ago (Previous week)
      expect(
        DateFormatter.getGroupBucket(DateTime(2026, 8, 10, 12, 0), now: now),
        'Previous week',
      );

      // 3 months ago (May)
      expect(
        DateFormatter.getGroupBucket(DateTime(2026, 5, 1, 12, 0), now: now),
        'May',
      );

      // Last year (2025)
      expect(
        DateFormatter.getGroupBucket(DateTime(2025, 12, 25, 12, 0), now: now),
        '2025',
      );
    });

    test('formatNoteTileTime returns clean relative strings', () {
      // Today -> time
      expect(
        DateFormatter.formatNoteTileTime(DateTime(2026, 8, 18, 14, 5), now: now),
        '2:05 PM',
      );

      // Yesterday -> "Yesterday"
      expect(
        DateFormatter.formatNoteTileTime(DateTime(2026, 8, 17, 10, 0), now: now),
        'Yesterday',
      );

      // This year -> "May 1"
      expect(
        DateFormatter.formatNoteTileTime(DateTime(2026, 5, 1, 10, 0), now: now),
        'May 1',
      );

      // Previous year -> "Dec 25, 2025"
      expect(
        DateFormatter.formatNoteTileTime(DateTime(2025, 12, 25, 10, 0), now: now),
        'Dec 25, 2025',
      );
    });

    test('groupByDate correctly separates pinned notes and groups remainder by bucket', () {
      final notes = [
        Note(
          id: 'p1',
          title: 'Pinned Note',
          content: 'body',
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
          isPinned: true,
        ),
        Note(
          id: 't1',
          title: 'Today Note',
          content: 'body',
          createdAt: DateTime(2026, 8, 18, 10),
          updatedAt: DateTime(2026, 8, 18, 10),
          isPinned: false,
        ),
        Note(
          id: 'y1',
          title: 'Yesterday Note',
          content: 'body',
          createdAt: DateTime(2026, 8, 17, 10),
          updatedAt: DateTime(2026, 8, 17, 10),
          isPinned: false,
        ),
      ];

      final groups = NoteGroup.groupByDate(notes, now: now);
      expect(groups.length, 3);
      expect(groups[0].header, 'Pinned');
      expect(groups[0].notes.first.id, 'p1');
      expect(groups[1].header, 'Today');
      expect(groups[1].notes.first.id, 't1');
      expect(groups[2].header, 'Yesterday');
      expect(groups[2].notes.first.id, 'y1');
    });
  });
}
