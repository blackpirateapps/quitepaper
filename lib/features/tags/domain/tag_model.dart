import 'package:flutter/foundation.dart';
import 'tag_colors.dart';
import 'tag_icon_registry.dart';

/// Tag filter criteria in the tag browser and navigation surfaces.
enum TagFilter {
  all('All Tags'),
  pinned('Pinned'),
  hasIcon('Has Icon'),
  hasColor('Has Color'),
  hasNotes('Has Notes'),
  unused('Unused');

  const TagFilter(this.label);
  final String label;
}

/// Tag sorting order in the tag browser.
enum TagSort {
  name('Name (A–Z)'),
  noteCount('Note count'),
  recentlyUsed('Recently updated'),
  recentlyCreated('Recently created'),
  custom('Custom (Pinned)');

  const TagSort(this.label);
  final String label;
}

/// Domain representation of a first-class synchronized Tag entity.
@immutable
class Tag {
  const Tag({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.isPinned = false,
    this.pinnedOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.noteCount = 0,
  });

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final bool isPinned;
  final int pinnedOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int noteCount;

  TagColorDefinition? get colorDefinition => TagColors.fromId(color);
  TagIconItem? get iconItem => TagIconRegistry.fromId(icon);

  Tag copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    bool? isPinned,
    int? pinnedOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? noteCount,
    bool clearIcon = false,
    bool clearColor = false,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: clearIcon ? null : (icon ?? this.icon),
      color: clearColor ? null : (color ?? this.color),
      isPinned: isPinned ?? this.isPinned,
      pinnedOrder: pinnedOrder ?? this.pinnedOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteCount: noteCount ?? this.noteCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        'isPinned': isPinned,
        'pinnedOrder': pinnedOrder,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Tag.fromJson(Map<String, dynamic> json, {int noteCount = 0}) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedOrder: json['pinnedOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      noteCount: noteCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          color == other.color &&
          isPinned == other.isPinned &&
          pinnedOrder == other.pinnedOrder &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          noteCount == other.noteCount;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      icon.hashCode ^
      color.hashCode ^
      isPinned.hashCode ^
      pinnedOrder.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      noteCount.hashCode;
}
