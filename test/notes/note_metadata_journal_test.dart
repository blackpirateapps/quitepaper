import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  final testNow = DateTime(2026, 10, 9, 9, 0, 0);

  Note journalNote(String id, String content) => Note(
        id: id,
        title: '',
        content: content,
        createdAt: testNow,
        updatedAt: testNow,
        journalDate: '2026-10-09',
      );

  setUp(NoteMetadataExtractor.clearCache);

  group('NoteMetadata journal metadata (§2.1)', () {
    const fullFrontmatter = '''---
journal: true
date: 2026-10-09
moment: travel
mood: 7
activities: [running, reading]
location:
  address: "Kolkata, West Bengal, India"
  latitude: 22.5726
  longitude: 88.3639
weather:
  temperature: 24.0
  condition: "Cloudy"
  code: 3
---

Woke up early and wandered the city.''';

    test('parses location, moment, mood, and weather into NoteMetadata', () {
      final meta = NoteMetadataExtractor.extract(journalNote('j1', fullFrontmatter));

      expect(meta.location, isNotNull);
      expect(meta.location!.address, 'Kolkata, West Bengal, India');
      expect(meta.location!.latitude, closeTo(22.5726, 0.0001));
      expect(meta.location!.longitude, closeTo(88.3639, 0.0001));
      expect(meta.moment, 'travel');
      expect(meta.mood, 7);
      expect(meta.weather, isNotNull);
      expect(meta.weather!.temperature, closeTo(24.0, 0.0001));
      expect(meta.weather!.code, 3);
    });

    test('locked notes expose no journal metadata', () {
      final locked = Note(
        id: 'locked',
        title: '',
        content:
            '<!-- quiet-paper-encrypted-note-v1:deadbeef -->\n$fullFrontmatter',
        createdAt: testNow,
        updatedAt: testNow,
        journalDate: '2026-10-09',
      );

      final meta = NoteMetadataExtractor.extract(locked);
      expect(meta.isPasswordProtected, isTrue);
      expect(meta.location, isNull);
      expect(meta.moment, isNull);
      expect(meta.mood, isNull);
      expect(meta.weather, isNull);
    });

    test('cache hit returns the same instance', () {
      final note = journalNote('j2', fullFrontmatter);
      final first = NoteMetadataExtractor.extract(note);
      final second = NoteMetadataExtractor.extract(note);
      expect(identical(first, second), isTrue);
    });

    test('entry with no location frontmatter yields null location', () {
      const noLocation = '''---
journal: true
date: 2026-10-09
moment: ordinary
---

A quiet day at home.''';
      final meta = NoteMetadataExtractor.extract(journalNote('j3', noLocation));
      expect(meta.location, isNull);
      expect(meta.moment, 'ordinary');
      expect(meta.weather, isNull);
      expect(meta.mood, isNull);
    });

    test('empty-coordinate blank-address location is treated as absent', () {
      const emptyLoc = '''---
journal: true
date: 2026-10-09
location:
  address: ""
  latitude: 0.0
  longitude: 0.0
---

No place recorded.''';
      final meta = NoteMetadataExtractor.extract(journalNote('j4', emptyLoc));
      expect(meta.location, isNull);
    });

    test('plain non-journal note has null journal metadata', () {
      final note = Note(
        id: 'plain',
        title: 'Groceries',
        content: 'Milk, eggs, bread.',
        createdAt: testNow,
        updatedAt: testNow,
      );
      final meta = NoteMetadataExtractor.extract(note);
      expect(meta.location, isNull);
      expect(meta.moment, isNull);
      expect(meta.mood, isNull);
      expect(meta.weather, isNull);
    });
  });
}
