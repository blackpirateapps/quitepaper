import 'package:flutter/widgets.dart';
import 'phosphor_icon_data_map.g.dart';
import 'phosphor_icons.dart';

/// Weight variants supported for Phosphor icons.
enum PhosphorIconWeight {
  regular,
  light,
  bold,
  fill,
}

/// Metadata definition for a Phosphor icon in the catalog.
@immutable
class PhosphorIconDefinition {
  const PhosphorIconDefinition({
    required this.id,
    required this.name,
    required this.pascalName,
    required this.camelName,
    required this.codePoint,
    this.categories = const [],
    this.tags = const [],
  });

  /// Canonical kebab-case identifier, e.g. "book-open", "heart", "camera".
  final String id;

  /// Human-readable display name, e.g. "Book Open", "Heart", "Camera".
  final String name;

  /// PascalCase name, e.g. "BookOpen".
  final String pascalName;

  /// camelCase name matching field in PhosphorIcons, e.g. "bookOpen".
  final String camelName;

  /// Unicode font codepoint.
  final int codePoint;

  /// Assigned categories.
  final List<String> categories;

  /// Search keywords and aliases.
  final List<String> tags;

  /// Stable namespaced key stored in SQLite, e.g. "phosphor:book-open".
  String get key => 'phosphor:$id';

  /// Resolves the icon glyph for the given weight (defaults to Regular).
  IconData getIconData([PhosphorIconWeight weight = PhosphorIconWeight.regular]) {
    switch (weight) {
      case PhosphorIconWeight.regular:
        return kPhosphorRegularIcons[id] ?? PhosphorIconsRegular.tag;
      case PhosphorIconWeight.light:
        return kPhosphorLightIcons[id] ?? PhosphorIconsLight.tag;
      case PhosphorIconWeight.bold:
        return kPhosphorBoldIcons[id] ?? PhosphorIconsBold.tag;
      case PhosphorIconWeight.fill:
        return kPhosphorFillIcons[id] ?? PhosphorIconsFill.tag;
    }
  }

  factory PhosphorIconDefinition.fromJson(Map<String, dynamic> json) {
    return PhosphorIconDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      pascalName: json['pascalName'] as String? ?? json['id'] as String,
      camelName: json['camelName'] as String? ?? json['id'] as String,
      codePoint: json['codePoint'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pascalName': pascalName,
        'camelName': camelName,
        'codePoint': codePoint,
        'categories': categories,
        'tags': tags,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhosphorIconDefinition &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PhosphorIconDefinition(id: $id, name: $name)';
}
