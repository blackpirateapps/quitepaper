import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/journal/application/place_grouping_service.dart';
import 'package:quitepaper/core/journal/domain/journal_place.dart';
import 'package:quitepaper/core/location/location_models.dart';

PlaceEntryInput _entry(
  String id,
  String address,
  DateTime date, {
  double lat = 0.0,
  double lng = 0.0,
}) {
  return PlaceEntryInput(
    noteId: id,
    location: JournalLocation(address: address, latitude: lat, longitude: lng),
    date: date,
  );
}

void main() {
  const service = PlaceGroupingService();

  group('normalizeKey', () {
    test('lowercases, trims, collapses whitespace', () {
      expect(
        PlaceGroupingService.normalizeKey('  New   York  '),
        equals('new york'),
      );
    });

    test('strips diacritics (Zürich -> zurich)', () {
      expect(PlaceGroupingService.normalizeKey('Zürich'), equals('zurich'));
      expect(PlaceGroupingService.normalizeKey('ZÜRICH'), equals('zurich'));
    });

    test('folds assorted accented letters', () {
      expect(PlaceGroupingService.normalizeKey('São Paulo'), equals('sao paulo'));
      expect(PlaceGroupingService.normalizeKey('Málaga'), equals('malaga'));
      expect(PlaceGroupingService.normalizeKey('Córdoba'), equals('cordoba'));
    });
  });

  group('haversineMeters', () {
    test('zero distance for identical points', () {
      expect(
        PlaceGroupingService.haversineMeters(22.5726, 88.3639, 22.5726, 88.3639),
        closeTo(0.0, 1e-6),
      );
    });

    test('one degree of latitude is ~111 km', () {
      final d = PlaceGroupingService.haversineMeters(0.0, 0.0, 1.0, 0.0);
      expect(d, closeTo(111195.0, 500.0));
    });

    test('known city-to-city distance (Kolkata -> Delhi ~1300 km)', () {
      final d = PlaceGroupingService.haversineMeters(
        22.5726,
        88.3639,
        28.6139,
        77.2090,
      );
      // Great-circle distance is ~1305 km.
      expect(d, closeTo(1305000.0, 20000.0));
    });
  });

  group('label grouping — City granularity', () {
    test('merges case/whitespace/diacritic variants into one place', () {
      final entries = [
        _entry('a', 'Zürich, Zürich, Switzerland', DateTime(2024, 1, 1)),
        _entry('b', 'zurich, Zurich, Switzerland', DateTime(2024, 2, 1)),
        _entry('c', '  ZURICH , Zurich, Switzerland', DateTime(2024, 3, 1)),
      ];

      final places = service.group(entries);

      expect(places, hasLength(1));
      final p = places.single;
      expect(p.matchKey, equals('zurich'));
      expect(p.entryCount, equals(3));
      expect(p.noteIds, equals(['a', 'b', 'c']));
      // Display keeps a pretty, original-casing label.
      expect(p.displayName, equals('Zürich'));
    });

    test('takes the first comma token as the city', () {
      final entries = [
        _entry('a', 'Kolkata, West Bengal, India', DateTime(2024, 1, 1)),
        _entry('b', 'Mumbai, Maharashtra, India', DateTime(2024, 1, 2)),
      ];

      final places = service.group(entries, sortOrder: PlaceSortOrder.alphabetical);
      expect(places.map((p) => p.matchKey), equals(['kolkata', 'mumbai']));
      expect(places.first.granularity, equals(PlaceGranularity.city));
    });

    test('date span is first -> last member date', () {
      final entries = [
        _entry('a', 'Kolkata, West Bengal, India', DateTime(2020, 6, 1)),
        _entry('b', 'Kolkata, West Bengal, India', DateTime(2026, 3, 15)),
        _entry('c', 'Kolkata, West Bengal, India', DateTime(2023, 1, 1)),
      ];
      final p = service.group(entries).single;
      expect(p.firstDate, equals(DateTime(2020, 6, 1)));
      expect(p.lastDate, equals(DateTime(2026, 3, 15)));
      expect(p.noteIds, equals(['a', 'c', 'b'])); // sorted by date asc.
    });

    test('entries with no location are excluded', () {
      final entries = [
        _entry('a', 'Kolkata, West Bengal, India', DateTime(2024, 1, 1)),
        _entry('b', '', DateTime(2024, 1, 2)), // isEmpty -> dropped.
      ];
      final places = service.group(entries);
      expect(places, hasLength(1));
      expect(places.single.noteIds, equals(['a']));
    });
  });

  group('granularity', () {
    final entries = [
      _entry('a', 'Kolkata, West Bengal, India', DateTime(2024, 1, 1)),
      _entry('b', 'Siliguri, West Bengal, India', DateTime(2024, 2, 1)),
      _entry('c', 'Mumbai, Maharashtra, India', DateTime(2024, 3, 1)),
      _entry('d', 'Kathmandu, Bagmati, Nepal', DateTime(2024, 4, 1)),
    ];

    test('City keeps each locality separate', () {
      final places = service.group(entries);
      expect(places, hasLength(4));
    });

    test('Region groups by city+region', () {
      final places = service.group(
        entries,
        granularity: PlaceGranularity.region,
        sortOrder: PlaceSortOrder.alphabetical,
      );
      // Kolkata and Siliguri share a region but differ in city -> stay apart.
      expect(places, hasLength(4));
      final kolkata = places.firstWhere((p) => p.matchKey.startsWith('kolkata'));
      expect(kolkata.matchKey, equals('kolkata|west bengal'));
      expect(kolkata.displayName, equals('Kolkata, West Bengal'));
    });

    test('Country collapses to the last token (travel lens)', () {
      final places = service.group(
        entries,
        granularity: PlaceGranularity.country,
        sortOrder: PlaceSortOrder.frequency,
      );
      expect(places, hasLength(2));
      final india = places.firstWhere((p) => p.matchKey == 'india');
      expect(india.entryCount, equals(3));
      expect(india.displayName, equals('India'));
      final nepal = places.firstWhere((p) => p.matchKey == 'nepal');
      expect(nepal.entryCount, equals(1));
      // Frequency order: India (3) before Nepal (1).
      expect(places.map((p) => p.matchKey), equals(['india', 'nepal']));
    });
  });

  group('alias / merge map', () {
    test('two labels fold into one canonical place with chosen display name', () {
      final entries = [
        _entry('a', 'Calcutta, West Bengal, India', DateTime(2010, 1, 1)),
        _entry('b', 'Kolkata, West Bengal, India', DateTime(2024, 1, 1)),
      ];
      // Remap the old-name key onto the canonical Kolkata key.
      final aliases = {
        'calcutta': const PlaceAlias(
          canonicalKey: 'kolkata',
          displayName: 'Kolkata',
        ),
      };

      final places = service.group(entries, aliases: aliases);
      expect(places, hasLength(1));
      final p = places.single;
      expect(p.matchKey, equals('kolkata'));
      expect(p.displayName, equals('Kolkata'));
      expect(p.entryCount, equals(2));
      expect(p.noteIds, equals(['a', 'b']));
    });

    test('alias can rename to a brand-new canonical key + display', () {
      final entries = [
        _entry('a', 'Bombay, Maharashtra, India', DateTime(2000, 1, 1)),
        _entry('b', 'Mumbai, Maharashtra, India', DateTime(2024, 1, 1)),
      ];
      final aliases = {
        'bombay': const PlaceAlias(canonicalKey: 'mumbai', displayName: 'Mumbai'),
        'mumbai': const PlaceAlias(canonicalKey: 'mumbai', displayName: 'Mumbai'),
      };
      final p = service.group(entries, aliases: aliases).single;
      expect(p.matchKey, equals('mumbai'));
      expect(p.displayName, equals('Mumbai'));
      expect(p.entryCount, equals(2));
    });
  });

  group('radius fallback — unlabeled coordinates', () {
    test('clusters nearby blank-address coords into one unnamed place', () {
      // Two points ~150 m apart (same block) with no address.
      final entries = [
        _entry('a', '', DateTime(2024, 1, 1), lat: 22.5726, lng: 88.3639),
        _entry('b', '', DateTime(2024, 1, 2), lat: 22.5739, lng: 88.3639),
      ];
      // ~145 m apart; a 300 m spot radius should merge them.
      final places = service.group(
        entries,
        coordinateClusterRadiusMeters: 300.0,
      );
      expect(places, hasLength(1));
      final p = places.single;
      expect(p.isUnnamed, isTrue);
      expect(p.entryCount, equals(2));
      expect(p.displayName, startsWith('Unnamed place near '));
      expect(p.displayName, contains('22.57'));
      expect(p.matchKey, startsWith('~coord:'));
    });

    test('does not merge coords beyond the radius', () {
      // ~1.1 km apart.
      final entries = [
        _entry('a', '', DateTime(2024, 1, 1), lat: 22.5726, lng: 88.3639),
        _entry('b', '', DateTime(2024, 1, 2), lat: 22.5826, lng: 88.3639),
      ];
      final places = service.group(
        entries,
        coordinateClusterRadiusMeters: 300.0,
      );
      expect(places, hasLength(2));
      for (final p in places) {
        expect(p.isUnnamed, isTrue);
        expect(p.entryCount, equals(1));
      }
    });

    test('neighborhood radius merges points that spot radius would split', () {
      final entries = [
        _entry('a', '', DateTime(2024, 1, 1), lat: 22.5726, lng: 88.3639),
        _entry('b', '', DateTime(2024, 1, 2), lat: 22.5826, lng: 88.3639),
      ];
      final merged = service.group(
        entries,
        coordinateClusterRadiusMeters:
            PlaceGroupingService.defaultNeighborhoodRadiusMeters,
      );
      expect(merged, hasLength(1));
      expect(merged.single.entryCount, equals(2));
    });

    test('labeled and unlabeled entries coexist in one result', () {
      final entries = [
        _entry('a', 'Kolkata, West Bengal, India', DateTime(2024, 1, 1)),
        _entry('b', '', DateTime(2024, 1, 2), lat: 22.5726, lng: 88.3639),
      ];
      final places = service.group(entries, sortOrder: PlaceSortOrder.firstSeen);
      expect(places, hasLength(2));
      expect(places.first.matchKey, equals('kolkata')); // first-seen 2024-01-01
      expect(places.last.isUnnamed, isTrue);
    });
  });

  group('sort orders', () {
    List<PlaceEntryInput> buildEntries() => [
          // Alpha: 3 entries, last 2024.
          _entry('a1', 'Alpha, Region, Country', DateTime(2020, 1, 1)),
          _entry('a2', 'Alpha, Region, Country', DateTime(2022, 1, 1)),
          _entry('a3', 'Alpha, Region, Country', DateTime(2024, 1, 1)),
          // Bravo: 1 entry, 2026 (most recent), earliest-seen 2026.
          _entry('b1', 'Bravo, Region, Country', DateTime(2026, 1, 1)),
          // Charlie: 2 entries, earliest overall 2018.
          _entry('c1', 'Charlie, Region, Country', DateTime(2018, 1, 1)),
          _entry('c2', 'Charlie, Region, Country', DateTime(2019, 1, 1)),
        ];

    test('frequency: count desc', () {
      final places = service.group(
        buildEntries(),
        sortOrder: PlaceSortOrder.frequency,
      );
      expect(
        places.map((p) => p.matchKey),
        equals(['alpha', 'charlie', 'bravo']),
      );
    });

    test('recency: latest date desc', () {
      final places = service.group(
        buildEntries(),
        sortOrder: PlaceSortOrder.recency,
      );
      expect(
        places.map((p) => p.matchKey),
        equals(['bravo', 'alpha', 'charlie']),
      );
    });

    test('firstSeen: earliest date asc', () {
      final places = service.group(
        buildEntries(),
        sortOrder: PlaceSortOrder.firstSeen,
      );
      expect(
        places.map((p) => p.matchKey),
        equals(['charlie', 'alpha', 'bravo']),
      );
    });

    test('alphabetical: display name A-Z', () {
      final places = service.group(
        buildEntries(),
        sortOrder: PlaceSortOrder.alphabetical,
      );
      expect(
        places.map((p) => p.displayName),
        equals(['Alpha', 'Bravo', 'Charlie']),
      );
    });

    test('ties fall back to matchKey for deterministic output', () {
      // Two single-entry places with identical dates/counts.
      final entries = [
        _entry('x', 'Yolo, Region, Country', DateTime(2024, 1, 1)),
        _entry('y', 'Avon, Region, Country', DateTime(2024, 1, 1)),
      ];
      final a = service.group(entries, sortOrder: PlaceSortOrder.frequency);
      final b = service.group(
        entries.reversed.toList(),
        sortOrder: PlaceSortOrder.frequency,
      );
      expect(a.map((p) => p.matchKey), equals(['avon', 'yolo']));
      expect(a.map((p) => p.matchKey), equals(b.map((p) => p.matchKey)));
    });
  });
}
