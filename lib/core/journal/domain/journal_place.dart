import 'package:flutter/foundation.dart';

/// How coarsely journal entries are grouped on the Places surface.
///
/// `city` is the default lens (one card per locality); `region` adds the
/// administrative region (`City, Region`); `country` is the travel-history
/// lens that collapses everything to a single country token.
enum PlaceGranularity { city, region, country }

/// User-facing orderings for a list of [JournalPlace]s.
///
/// Every ordering falls back to [JournalPlace.matchKey] on ties so the output
/// is stable and deterministic regardless of input order.
enum PlaceSortOrder {
  /// Most-written places first (entry count descending).
  frequency,

  /// Most recently visited first (latest member date descending).
  recency,

  /// Chronological discovery (earliest member date ascending) — good for travel.
  firstSeen,

  /// Case-insensitive A–Z by display name.
  alphabetical,
}

/// An aggregate of journal entries that share a normalized place.
///
/// Grouping is label-first (normalized city/region/country token) with a
/// coordinate-radius fallback for entries whose geocode failed. A place keeps a
/// pretty [displayName] (original casing/diacritics) distinct from its
/// normalized [matchKey], the [granularity] it was grouped at, the member
/// [noteIds], and the [firstDate]→[lastDate] span.
@immutable
class JournalPlace {
  const JournalPlace({
    required this.displayName,
    required this.matchKey,
    required this.granularity,
    required this.noteIds,
    required this.firstDate,
    required this.lastDate,
    this.isUnnamed = false,
  });

  /// Pretty, human-facing label (keeps original casing and diacritics).
  final String displayName;

  /// Normalized identity used to merge entries (lowercased, trimmed,
  /// whitespace-collapsed, diacritics-stripped). Never shown to the user.
  final String matchKey;

  /// The granularity this place was grouped at.
  final PlaceGranularity granularity;

  /// Member note ids, sorted by entry date ascending then id (stable).
  final List<String> noteIds;

  /// Earliest member entry date.
  final DateTime firstDate;

  /// Latest member entry date.
  final DateTime lastDate;

  /// True when this is a radius-clustered blob of coordinates with no label
  /// (its [displayName] reads like `Unnamed place near 22.57, 88.36`).
  final bool isUnnamed;

  /// Number of member entries.
  int get entryCount => noteIds.length;

  /// Whether every member entry falls on a single calendar instant span.
  bool get isSingleVisit => firstDate == lastDate;

  /// A comparator implementing [order], with [matchKey] as a stable tiebreak.
  static Comparator<JournalPlace> comparatorFor(PlaceSortOrder order) {
    return (a, b) {
      int primary;
      switch (order) {
        case PlaceSortOrder.frequency:
          primary = b.entryCount.compareTo(a.entryCount);
          break;
        case PlaceSortOrder.recency:
          primary = b.lastDate.compareTo(a.lastDate);
          break;
        case PlaceSortOrder.firstSeen:
          primary = a.firstDate.compareTo(b.firstDate);
          break;
        case PlaceSortOrder.alphabetical:
          primary = a.displayName.toLowerCase().compareTo(
                b.displayName.toLowerCase(),
              );
          break;
      }
      if (primary != 0) return primary;
      return a.matchKey.compareTo(b.matchKey);
    };
  }

  /// Returns a new list of [places] ordered by [order] (non-mutating).
  static List<JournalPlace> sorted(
    List<JournalPlace> places,
    PlaceSortOrder order,
  ) {
    final copy = List<JournalPlace>.of(places);
    copy.sort(comparatorFor(order));
    return copy;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalPlace &&
          runtimeType == other.runtimeType &&
          matchKey == other.matchKey &&
          granularity == other.granularity;

  @override
  int get hashCode => Object.hash(matchKey, granularity);

  @override
  String toString() =>
      'JournalPlace($displayName [$matchKey], ${granularity.name}, '
      'count: $entryCount)';
}
