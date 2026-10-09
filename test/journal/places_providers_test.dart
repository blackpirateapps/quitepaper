import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/journal/domain/journal_place.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/application/place_alias_store.dart';
import 'package:quitepaper/features/journal/application/places_providers.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

/// Builds a journal note. When [address] is null, the note has no location
/// frontmatter; when [locked], it is encrypted (and must be excluded).
Note _note(
  String id,
  String date, {
  String? address,
  bool locked = false,
}) {
  final dt = DateTime.parse(date);
  final String content;
  if (locked) {
    content = '<!-- quiet-paper-encrypted-note-v1: $id -->\ncipher';
  } else if (address != null) {
    content = '''---
journal: true
date: $date
location:
  address: "$address"
  latitude: 1.0
  longitude: 2.0
---

Entry for $date.''';
  } else {
    content = '''---
journal: true
date: $date
---

Entry for $date.''';
  }
  return Note(
    id: id,
    title: 'Entry',
    content: content,
    createdAt: dt,
    updatedAt: dt,
    journalDate: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NoteMetadataExtractor.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> containerFor(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allJournalEntriesStreamProvider.overrideWith((ref) => Stream.value(notes)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(allJournalEntriesStreamProvider.future);
    return container;
  }

  group('placeListProvider', () {
    test('silently excludes unlocated and locked notes; groups located ones',
        () async {
      final notes = [
        _note('n1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('n2', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
        _note('n3', '2026-09-25'), // no location → excluded
        _note('n4', '2026-09-26',
            address: 'Delhi, Delhi, India', locked: true), // locked → excluded
      ];
      final c = await containerFor(notes);

      final places = c.read(placeListProvider);
      expect(places.map((p) => p.matchKey).toSet(), {'kolkata', 'mumbai'});
      expect(places.fold<int>(0, (s, p) => s + p.entryCount), 2);
    });

    test('is empty while the entries stream is still loading', () {
      final container = ProviderContainer(
        overrides: [
          allJournalEntriesStreamProvider
              .overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(placeListProvider), isEmpty);
    });

    test('country granularity collapses cities into one country place',
        () async {
      final notes = [
        _note('n1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('n2', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
      ];
      final c = await containerFor(notes);
      c.read(placeGranularityProvider.notifier).state = PlaceGranularity.country;

      final places = c.read(placeListProvider);
      expect(places.length, 1);
      expect(places.single.matchKey, 'india');
      expect(places.single.entryCount, 2);
    });

    test('sort order is honored (recency default vs alphabetical)', () async {
      final notes = [
        _note('n1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('n2', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
      ];
      final c = await containerFor(notes);

      // Default recency → most recent entry's place first (Mumbai @ 09-20).
      expect(c.read(placeListProvider).first.matchKey, 'mumbai');

      c.read(placeSortOrderProvider.notifier).state = PlaceSortOrder.alphabetical;
      expect(c.read(placeListProvider).first.matchKey, 'kolkata');
    });

    test('alias map merges distinct keys into one canonical place', () async {
      final notes = [
        _note('n1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('n5', '2026-09-05', address: 'Calcutta, West Bengal, India'),
        _note('n2', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
      ];
      final c = await containerFor(notes);

      // Three distinct city places before merging.
      expect(c.read(placeListProvider).length, 3);

      c.read(placeAliasStoreProvider.notifier).merge(
        ['calcutta'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );

      final places = c.read(placeListProvider);
      expect(places.length, 2);
      final kolkata = places.firstWhere((p) => p.matchKey == 'kolkata');
      expect(kolkata.entryCount, 2);
      expect(kolkata.displayName, 'Kolkata');
    });
  });

  group('placeEntriesProvider', () {
    test('returns a place\'s member notes reverse-chronologically', () async {
      final notes = [
        _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('k2', '2026-09-18', address: 'Kolkata, West Bengal, India'),
        _note('m1', '2026-09-20', address: 'Mumbai, Maharashtra, India'),
      ];
      final c = await containerFor(notes);

      final kolkata = c.read(placeEntriesProvider('kolkata'));
      expect(kolkata.map((n) => n.id).toList(), ['k2', 'k1']);

      expect(c.read(placeEntriesProvider('unknown-key')), isEmpty);
    });
  });

  group('placeVisitsProvider', () {
    test('clusters a place\'s entries into visits', () async {
      final notes = [
        _note('k1', '2026-09-10', address: 'Kolkata, West Bengal, India'),
        _note('k2', '2026-09-12', address: 'Kolkata, West Bengal, India'),
      ];
      final c = await containerFor(notes);
      final visits = c.read(placeVisitsProvider('kolkata'));
      expect(visits.length, 1);
      expect(visits.single.entryCount, 2);
    });
  });
}
