import 'package:flutter/foundation.dart';
import 'notes_query.dart';

/// User-saved filter preset / smart view
@immutable
class SavedFilter {
  const SavedFilter({
    required this.id,
    required this.name,
    required this.query,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final NotesQuery query;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedFilter copyWith({
    String? id,
    String? name,
    NotesQuery? query,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedFilter(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'query': query.copyWith(clearCursor: true, generation: 0).toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedFilter.fromJson(Map<String, dynamic> json) {
    return SavedFilter(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled View',
      query: NotesQuery.fromJson(json['query'] as Map<String, dynamic>?),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedFilter &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          query == other.query &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      query.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() => 'SavedFilter(id: $id, name: $name, query: $query)';
}
