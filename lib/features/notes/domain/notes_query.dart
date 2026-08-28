import 'package:flutter/foundation.dart';
import 'notes_cursor.dart';
import 'notes_filter.dart';
import 'notes_sort.dart';

/// Centralized, immutable specification for querying, sorting, and paginating notes
@immutable
class NotesQuery {
  const NotesQuery({
    this.context = NotesContext.active,
    this.filter = NotesFilter.empty,
    this.sort = NotesSort.defaultSort,
    this.searchQuery,
    this.cursor,
    this.limit = defaultBatchSize,
    this.generation = 0,
  });

  /// Default and max query batch limits
  static const int defaultBatchSize = 40;
  static const int maxBatchSize = 100;
  static const int schemaVersion = 1;

  final NotesContext context;
  final NotesFilter filter;
  final NotesSort sort;
  final String? searchQuery;
  final NotesCursor? cursor;
  final int limit;
  final int generation;

  /// Default active notes query
  static const defaultQuery = NotesQuery();

  /// Creates a query for a given context and optional tag
  factory NotesQuery.forDestination({
    required NotesContext context,
    String? tag,
    bool pinnedOnly = false,
  }) {
    return NotesQuery(
      context: context,
      filter: NotesFilter(
        tags: tag != null && tag.isNotEmpty ? {tag} : const {},
        pinnedOnly: pinnedOnly,
      ),
    );
  }

  /// Resets pagination and updates generation ID on predicate/sort/context change
  NotesQuery resetPagination({int? newGeneration}) {
    return copyWith(
      clearCursor: true,
      generation: newGeneration ?? (generation + 1),
    );
  }

  /// Advances cursor to next page for the same query generation
  NotesQuery nextPage(NotesCursor nextCursor) {
    return copyWith(
      cursor: nextCursor,
    );
  }

  NotesQuery copyWith({
    NotesContext? context,
    NotesFilter? filter,
    NotesSort? sort,
    String? searchQuery,
    bool clearSearchQuery = false,
    NotesCursor? cursor,
    bool clearCursor = false,
    int? limit,
    int? generation,
  }) {
    final effectiveLimit = (limit ?? this.limit).clamp(1, maxBatchSize);
    return NotesQuery(
      context: context ?? this.context,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      limit: effectiveLimit,
      generation: generation ?? this.generation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': schemaVersion,
      'context': context.name,
      'filter': filter.toJson(),
      'sort': sort.toJson(),
      if (searchQuery != null && searchQuery!.isNotEmpty) 'searchQuery': searchQuery,
      if (cursor != null) 'cursor': cursor!.toJson(),
      'limit': limit,
    };
  }

  factory NotesQuery.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultQuery;

    return NotesQuery(
      context: NotesContext.fromString(json['context'] as String?),
      filter: NotesFilter.fromJson(json['filter'] as Map<String, dynamic>?),
      sort: NotesSort.fromJson(json['sort'] as Map<String, dynamic>?),
      searchQuery: json['searchQuery'] as String?,
      cursor: json['cursor'] != null
          ? NotesCursor.fromJson(json['cursor'] as Map<String, dynamic>?)
          : null,
      limit: (json['limit'] as int? ?? defaultBatchSize).clamp(1, maxBatchSize),
      generation: 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesQuery &&
          runtimeType == other.runtimeType &&
          context == other.context &&
          filter == other.filter &&
          sort == other.sort &&
          searchQuery == other.searchQuery &&
          cursor == other.cursor &&
          limit == other.limit &&
          generation == other.generation;

  @override
  int get hashCode =>
      context.hashCode ^
      filter.hashCode ^
      sort.hashCode ^
      searchQuery.hashCode ^
      cursor.hashCode ^
      limit.hashCode ^
      generation.hashCode;

  @override
  String toString() =>
      'NotesQuery(context: $context, filter: $filter, sort: $sort, query: $searchQuery, cursor: $cursor, gen: $generation)';
}
