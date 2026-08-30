import 'package:flutter/material.dart';

/// Representation of a curated tag color definition.
@immutable
class TagColorDefinition {
  const TagColorDefinition({
    required this.id,
    required this.label,
    required this.lightColor,
    required this.darkColor,
    required this.lightBgColor,
    required this.darkBgColor,
  });

  final String id;
  final String label;
  final Color lightColor;
  final Color darkColor;
  final Color lightBgColor;
  final Color darkBgColor;

  Color foreground(bool isDark) => isDark ? darkColor : lightColor;
  Color background(bool isDark) => isDark ? darkBgColor : lightBgColor;
}

/// Curated 8-color Warm Editorial Tag Color Palette for Quiet Paper.
abstract final class TagColors {
  static const coral = TagColorDefinition(
    id: 'coral',
    label: 'Coral',
    lightColor: Color(0xFFE06C53),
    darkColor: Color(0xFFE87D65),
    lightBgColor: Color(0x22E06C53),
    darkBgColor: Color(0x28E87D65),
  );

  static const amber = TagColorDefinition(
    id: 'amber',
    label: 'Amber',
    lightColor: Color(0xFFD9822B),
    darkColor: Color(0xFFE59547),
    lightBgColor: Color(0x22D9822B),
    darkBgColor: Color(0x28E59547),
  );

  static const sage = TagColorDefinition(
    id: 'sage',
    label: 'Sage',
    lightColor: Color(0xFF4E8763),
    darkColor: Color(0xFF6EAA84),
    lightBgColor: Color(0x224E8763),
    darkBgColor: Color(0x286EAA84),
  );

  static const teal = TagColorDefinition(
    id: 'teal',
    label: 'Teal',
    lightColor: Color(0xFF328590),
    darkColor: Color(0xFF48A2AF),
    lightBgColor: Color(0x22328590),
    darkBgColor: Color(0x2848A2AF),
  );

  static const indigo = TagColorDefinition(
    id: 'indigo',
    label: 'Indigo',
    lightColor: Color(0xFF47669A),
    darkColor: Color(0xFF6586BD),
    lightBgColor: Color(0x2247669A),
    darkBgColor: Color(0x286586BD),
  );

  static const lavender = TagColorDefinition(
    id: 'lavender',
    label: 'Lavender',
    lightColor: Color(0xFF755998),
    darkColor: Color(0xFF957BB8),
    lightBgColor: Color(0x22755998),
    darkBgColor: Color(0x28957BB8),
  );

  static const rose = TagColorDefinition(
    id: 'rose',
    label: 'Rose',
    lightColor: Color(0xFFC0526F),
    darkColor: Color(0xFFD86E8A),
    lightBgColor: Color(0x22C0526F),
    darkBgColor: Color(0x28D86E8A),
  );

  static const slate = TagColorDefinition(
    id: 'slate',
    label: 'Slate',
    lightColor: Color(0xFF636A78),
    darkColor: Color(0xFF8B93A0),
    lightBgColor: Color(0x22636A78),
    darkBgColor: Color(0x288B93A0),
  );

  static const List<TagColorDefinition> all = [
    coral,
    amber,
    sage,
    teal,
    indigo,
    lavender,
    rose,
    slate,
  ];

  static TagColorDefinition? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    final normalized = id.toLowerCase().trim();
    for (final c in all) {
      if (c.id == normalized) return c;
    }
    return null;
  }
}
