import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../location/location_models.dart';
import '../domain/journal_place.dart';

/// A single journal entry reduced to the fields the grouper needs.
///
/// Kept intentionally decoupled from `Note`/`NoteMetadata` so the grouping
/// logic stays pure and unit-testable; the caller (Places page) adapts notes
/// into this shape.
@immutable
class PlaceEntryInput {
  const PlaceEntryInput({
    required this.noteId,
    required this.location,
    required this.date,
  });

  /// Stable id of the source note.
  final String noteId;

  /// The entry's captured location frontmatter.
  final JournalLocation location;

  /// The entry's journal date (used for the place's date span).
  final DateTime date;
}

/// A user merge/alias target: fold a normalized match key into [canonicalKey]
/// and show it as [displayName].
///
/// The alias store itself (synced vault record, §2.3) is built later; this
/// service only consumes a `Map<String, PlaceAlias>` keyed by the *normalized*
/// match key being remapped.
@immutable
class PlaceAlias {
  const PlaceAlias({required this.canonicalKey, required this.displayName});

  /// The normalized key this alias collapses into.
  final String canonicalKey;

  /// The pretty label to show for the merged place.
  final String displayName;
}

/// Groups journal entries into [JournalPlace] aggregates.
///
/// **Label-first, radius-second — never exact-coordinate match** (GPS jitter
/// guarantees exact coords never repeat):
///
/// 1. Entries with a non-blank [JournalLocation.address] are keyed by a
///    normalized label token derived per [PlaceGranularity] (city / city+region
///    / country).
/// 2. Entries with a blank address but non-zero coords are clustered by
///    haversine proximity and named `Unnamed place near <lat>, <lng>`.
/// 3. Entries with no location at all ([JournalLocation.isEmpty]) are excluded.
///
/// Output is deterministic: entries are processed in a stable order and the
/// returned list is ordered by [sortOrder] with a [JournalPlace.matchKey]
/// tiebreak.
class PlaceGroupingService {
  const PlaceGroupingService();

  /// Tight "same building/block" clustering radius (§2.2 spot tier).
  static const double defaultSpotRadiusMeters = 250.0;

  /// Looser "same neighborhood" clustering radius (§2.2 neighborhood tier).
  /// Used as the default for naming/merging unlabeled coordinate blobs.
  static const double defaultNeighborhoodRadiusMeters = 1500.0;

  /// Mean Earth radius in meters (used by [haversineMeters]).
  static const double earthRadiusMeters = 6371000.0;

  /// Groups [entries] into places.
  ///
  /// - [granularity] picks the label token (city default).
  /// - [aliases] remaps/renames normalized keys (default empty).
  /// - [sortOrder] orders the returned list (default [PlaceSortOrder.frequency]).
  /// - [coordinateClusterRadiusMeters] is the proximity threshold for the
  ///   radius fallback on unlabeled coordinate blobs.
  List<JournalPlace> group(
    List<PlaceEntryInput> entries, {
    PlaceGranularity granularity = PlaceGranularity.city,
    Map<String, PlaceAlias> aliases = const {},
    PlaceSortOrder sortOrder = PlaceSortOrder.frequency,
    double coordinateClusterRadiusMeters = defaultNeighborhoodRadiusMeters,
  }) {
    // Partition into labeled vs unlabeled-with-coords, dropping no-location.
    final labeled = <PlaceEntryInput>[];
    final unlabeled = <PlaceEntryInput>[];
    for (final e in entries) {
      final loc = e.location;
      if (loc.isEmpty) continue; // no location → excluded entirely.
      if (loc.address.trim().isNotEmpty) {
        labeled.add(e);
      } else {
        // Blank address but non-zero coords (geocode failed).
        unlabeled.add(e);
      }
    }

    final accumulators = <String, _PlaceAccumulator>{};

    _groupLabeled(labeled, granularity, aliases, accumulators);
    _groupByRadius(unlabeled, coordinateClusterRadiusMeters, accumulators);

    final places = accumulators.values
        .map((a) => a.build(granularity))
        .toList(growable: false);
    return JournalPlace.sorted(places, sortOrder);
  }

  // --- Label grouping ---------------------------------------------------------

  void _groupLabeled(
    List<PlaceEntryInput> labeled,
    PlaceGranularity granularity,
    Map<String, PlaceAlias> aliases,
    Map<String, _PlaceAccumulator> accumulators,
  ) {
    // Stable processing order so the chosen display label is deterministic.
    final ordered = List<PlaceEntryInput>.of(labeled)..sort(_byDateThenId);
    for (final e in ordered) {
      final tokens = _addressTokens(e.location.address);
      if (tokens.isEmpty) continue;

      final rawKey = _matchKeyFor(tokens, granularity);
      var displayName = _displayLabelFor(tokens, granularity);
      var key = rawKey;
      var fromAlias = false;

      final alias = aliases[rawKey];
      if (alias != null) {
        key = alias.canonicalKey;
        displayName = alias.displayName;
        fromAlias = true;
      }

      final acc = accumulators.putIfAbsent(
        key,
        () => _PlaceAccumulator(matchKey: key),
      );
      acc.addLabeled(
        noteId: e.noteId,
        date: e.date,
        displayName: displayName,
        fromAlias: fromAlias,
      );
    }
  }

  // --- Radius fallback --------------------------------------------------------

  void _groupByRadius(
    List<PlaceEntryInput> unlabeled,
    double radiusMeters,
    Map<String, _PlaceAccumulator> accumulators,
  ) {
    if (unlabeled.isEmpty) return;

    // Deterministic seed order: by coordinate then id.
    final ordered = List<PlaceEntryInput>.of(unlabeled)
      ..sort((a, b) {
        final latCmp = a.location.latitude.compareTo(b.location.latitude);
        if (latCmp != 0) return latCmp;
        final lngCmp = a.location.longitude.compareTo(b.location.longitude);
        if (lngCmp != 0) return lngCmp;
        return a.noteId.compareTo(b.noteId);
      });

    final clusters = <_CoordCluster>[];
    for (final e in ordered) {
      final lat = e.location.latitude;
      final lng = e.location.longitude;
      _CoordCluster? target;
      for (final c in clusters) {
        if (haversineMeters(c.seedLat, c.seedLng, lat, lng) <= radiusMeters) {
          target = c;
          break;
        }
      }
      if (target == null) {
        target = _CoordCluster(lat, lng);
        clusters.add(target);
      }
      target.add(e);
    }

    for (final c in clusters) {
      final latStr = c.centroidLat.toStringAsFixed(2);
      final lngStr = c.centroidLng.toStringAsFixed(2);
      final key = '~coord:$latStr,$lngStr';
      final displayName = 'Unnamed place near $latStr, $lngStr';
      final acc = accumulators.putIfAbsent(
        key,
        () => _PlaceAccumulator(matchKey: key, isUnnamed: true),
      );
      for (final e in c.members) {
        acc.addLabeled(
          noteId: e.noteId,
          date: e.date,
          displayName: displayName,
          fromAlias: true, // force the computed unnamed label to win.
        );
      }
    }
  }

  // --- Token extraction -------------------------------------------------------

  /// Splits an address into trimmed, non-empty comma tokens.
  static List<String> _addressTokens(String address) {
    return address
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  /// The normalized match key for [tokens] at [granularity].
  static String _matchKeyFor(List<String> tokens, PlaceGranularity g) {
    switch (g) {
      case PlaceGranularity.city:
        return normalizeKey(tokens.first);
      case PlaceGranularity.region:
        final region = _regionToken(tokens);
        final cityKey = normalizeKey(tokens.first);
        if (region == null) return cityKey;
        return '$cityKey|${normalizeKey(region)}';
      case PlaceGranularity.country:
        return normalizeKey(tokens.last);
    }
  }

  /// The pretty display label for [tokens] at [granularity].
  static String _displayLabelFor(List<String> tokens, PlaceGranularity g) {
    switch (g) {
      case PlaceGranularity.city:
        return tokens.first;
      case PlaceGranularity.region:
        final region = _regionToken(tokens);
        if (region == null) return tokens.first;
        return '${tokens.first}, $region';
      case PlaceGranularity.country:
        return tokens.last;
    }
  }

  /// The administrative region token: the token just before the country when
  /// there are 3+ tokens (`[city, region, country]`); null otherwise.
  static String? _regionToken(List<String> tokens) {
    if (tokens.length >= 3) return tokens[tokens.length - 2];
    return null;
  }

  // --- Normalization ----------------------------------------------------------

  /// Normalizes a label into a match key: lowercase, strip diacritics,
  /// collapse internal whitespace, trim.
  static String normalizeKey(String raw) {
    final lowered = raw.toLowerCase().trim();
    final stripped = _stripDiacritics(lowered);
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripDiacritics(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Common Latin diacritic → base-letter folding (lowercase only; callers
  /// lowercase first). Deliberately small and dependency-free.
  static const Map<String, String> _diacritics = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
    'ð': 'd', 'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
    'ę': 'e', 'ě': 'e',
    'ğ': 'g', 'ĝ': 'g', 'ġ': 'g', 'ģ': 'g',
    'ĥ': 'h', 'ħ': 'h',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i',
    'į': 'i', 'ı': 'i',
    'ĵ': 'j',
    'ķ': 'k',
    'ł': 'l', 'ĺ': 'l', 'ļ': 'l', 'ľ': 'l',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ŏ': 'o', 'ő': 'o',
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
    'ś': 's', 'š': 's', 'ş': 's', 'ŝ': 's', 'ș': 's',
    'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u',
    'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ŵ': 'w',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ž': 'z', 'ż': 'z', 'ź': 'z',
    'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  };

  // --- Haversine --------------------------------------------------------------

  /// Great-circle distance in meters between two lat/lng points.
  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final rLat1 = _toRadians(lat1);
    final rLat2 = _toRadians(lat2);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  static int _byDateThenId(PlaceEntryInput a, PlaceEntryInput b) {
    final dateCmp = a.date.compareTo(b.date);
    if (dateCmp != 0) return dateCmp;
    return a.noteId.compareTo(b.noteId);
  }
}

/// Mutable builder for one place while grouping is in progress.
class _PlaceAccumulator {
  _PlaceAccumulator({required this.matchKey, this.isUnnamed = false});

  final String matchKey;
  final bool isUnnamed;
  final List<_Member> _members = [];
  String? _displayName;
  bool _displayFromAlias = false;

  void addLabeled({
    required String noteId,
    required DateTime date,
    required String displayName,
    required bool fromAlias,
  }) {
    _members.add(_Member(noteId, date));
    // Alias/computed labels win; otherwise first-seen label wins (stable).
    if (_displayName == null || (fromAlias && !_displayFromAlias)) {
      _displayName = displayName;
      _displayFromAlias = fromAlias;
    }
  }

  JournalPlace build(PlaceGranularity granularity) {
    final members = List<_Member>.of(_members)
      ..sort((a, b) {
        final dateCmp = a.date.compareTo(b.date);
        if (dateCmp != 0) return dateCmp;
        return a.noteId.compareTo(b.noteId);
      });
    final noteIds = members.map((m) => m.noteId).toList(growable: false);
    final first = members.first.date;
    final last = members.last.date;
    return JournalPlace(
      displayName: _displayName ?? matchKey,
      matchKey: matchKey,
      granularity: granularity,
      noteIds: noteIds,
      firstDate: first,
      lastDate: last,
      isUnnamed: isUnnamed,
    );
  }
}

class _Member {
  const _Member(this.noteId, this.date);
  final String noteId;
  final DateTime date;
}

/// A greedy proximity cluster anchored on its first (seed) point.
class _CoordCluster {
  _CoordCluster(this.seedLat, this.seedLng);

  final double seedLat;
  final double seedLng;
  final List<PlaceEntryInput> members = [];

  void add(PlaceEntryInput e) => members.add(e);

  double get centroidLat =>
      members.map((e) => e.location.latitude).reduce((a, b) => a + b) /
      members.length;

  double get centroidLng =>
      members.map((e) => e.location.longitude).reduce((a, b) => a + b) /
      members.length;
}
