import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/journal/domain/journal_visit.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

Note _note(String id, String date) {
  final dt = DateTime.parse(date);
  return Note(
    id: id,
    title: 'Entry',
    content: '---\njournal: true\ndate: $date\n---\nBody.',
    createdAt: dt,
    updatedAt: dt,
    journalDate: date,
  );
}

void main() {
  group('clusterVisits', () {
    test('empty input yields no visits', () {
      expect(clusterVisits(const []), isEmpty);
    });

    test('entries within the gap threshold form a single visit', () {
      final notes = [
        _note('a', '2024-10-20'),
        _note('b', '2024-10-05'),
        _note('c', '2024-10-01'),
      ];
      final visits = clusterVisits(notes);
      expect(visits.length, 1);
      expect(visits.single.entryCount, 3);
      expect(visits.single.label, 'October 2024');
      expect(visits.single.start, DateTime(2024, 10, 1));
      expect(visits.single.end, DateTime(2024, 10, 20));
      // Member ids newest-first.
      expect(visits.single.noteIds, ['a', 'b', 'c']);
    });

    test('a gap larger than the threshold splits into separate visits', () {
      final notes = [
        _note('a', '2024-10-01'),
        _note('b', '2024-10-10'),
        _note('c', '2024-12-15'), // >30 days after Oct 10 → new visit
        _note('d', '2024-12-20'),
      ];
      final visits = clusterVisits(notes);
      expect(visits.length, 2);
      // Newest visit first.
      expect(visits.first.label, 'December 2024');
      expect(visits.first.entryCount, 2);
      expect(visits.last.label, 'October 2024');
      expect(visits.last.entryCount, 2);
    });

    test('a visit spanning months is labeled as a range', () {
      final notes = [
        _note('a', '2024-10-25'),
        _note('b', '2024-11-10'), // 16 days later → same visit, crosses month
      ];
      final visits = clusterVisits(notes);
      expect(visits.length, 1);
      expect(visits.single.label, 'October 2024 – November 2024');
    });

    test('clustering is deterministic regardless of input order', () {
      final dates = ['2024-10-01', '2024-10-15', '2024-12-20', '2025-01-02'];
      final forward = [for (final d in dates) _note(d, d)];
      final reversed = forward.reversed.toList();

      final a = clusterVisits(forward);
      final b = clusterVisits(reversed);
      expect(a, equals(b));
      // Oct cluster, then Dec20+Jan02 (13-day gap) cluster.
      expect(a.length, 2);
    });

    test('respects a custom gap threshold', () {
      final notes = [
        _note('a', '2024-10-01'),
        _note('b', '2024-10-10'), // 9-day gap
      ];
      // With a 5-day threshold these split into two visits.
      expect(clusterVisits(notes, gapThresholdDays: 5).length, 2);
      // With the default 30-day threshold they stay together.
      expect(clusterVisits(notes).length, 1);
    });
  });
}
