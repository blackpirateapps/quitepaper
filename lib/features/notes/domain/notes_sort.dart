import 'package:flutter/foundation.dart';

/// Supported primary fields for ordering notes
enum SortField {
  updated,
  created,
  title;

  String get displayName {
    switch (this) {
      case SortField.updated:
        return 'Recently Updated';
      case SortField.created:
        return 'Recently Created';
      case SortField.title:
        return 'Title';
    }
  }

  static SortField fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'created':
        return SortField.created;
      case 'title':
        return SortField.title;
      case 'updated':
      default:
        return SortField.updated;
    }
  }
}

/// Ordering directions
enum SortDirection {
  ascending,
  descending;

  String getDisplayName(SortField field) {
    if (field == SortField.title) {
      return this == SortDirection.ascending ? 'A → Z' : 'Z → A';
    }
    return this == SortDirection.descending ? 'Newest First' : 'Oldest First';
  }

  static SortDirection fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'asc':
      case 'ascending':
        return SortDirection.ascending;
      case 'desc':
      case 'descending':
      default:
        return SortDirection.descending;
    }
  }
}

/// Immutable sort specification for notes list queries
@immutable
class NotesSort {
  const NotesSort({
    this.field = SortField.updated,
    this.direction = SortDirection.descending,
    this.pinnedFirst = true,
  });

  final SortField field;
  final SortDirection direction;
  final bool pinnedFirst;

  /// Default sort configuration
  static const defaultSort = NotesSort(
    field: SortField.updated,
    direction: SortDirection.descending,
    pinnedFirst: true,
  );

  NotesSort copyWith({
    SortField? field,
    SortDirection? direction,
    bool? pinnedFirst,
  }) {
    return NotesSort(
      field: field ?? this.field,
      direction: direction ?? this.direction,
      pinnedFirst: pinnedFirst ?? this.pinnedFirst,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field': field.name,
      'direction': direction == SortDirection.ascending ? 'asc' : 'desc',
      'pinnedFirst': pinnedFirst,
    };
  }

  factory NotesSort.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultSort;
    return NotesSort(
      field: SortField.fromString(json['field'] as String?),
      direction: SortDirection.fromString(json['direction'] as String?),
      pinnedFirst: json['pinnedFirst'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesSort &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          direction == other.direction &&
          pinnedFirst == other.pinnedFirst;

  @override
  int get hashCode => field.hashCode ^ direction.hashCode ^ pinnedFirst.hashCode;

  @override
  String toString() => 'NotesSort(field: $field, direction: $direction, pinnedFirst: $pinnedFirst)';
}
