import 'package:flutter/material.dart';
import 'phosphor_icon_data_map.g.dart';
import 'phosphor_icons.dart';
import 'tag_icon_definition.dart';

/// Legacy category enum preserved for backward compatibility.
enum TagIconCategory {
  all('All'),
  recent('Recent'),
  favorites('Favorites'),
  activity('Activity'),
  arrows('Arrows'),
  brands('Brands'),
  buildings('Buildings'),
  communication('Communication'),
  design('Design'),
  development('Development'),
  education('Education'),
  files('Files'),
  finance('Finance'),
  food('Food & Drink'),
  health('Health'),
  maps('Maps & Travel'),
  media('Media'),
  nature('Nature'),
  objects('Objects'),
  people('People'),
  places('Places'),
  science('Science'),
  security('Security'),
  shapes('Shapes'),
  system('System'),
  technology('Technology'),
  transportation('Transportation'),
  weather('Weather');

  const TagIconCategory(this.displayName);
  final String displayName;
}

/// Backward compatibility item wrapping PhosphorIconDefinition.
typedef TagIconItem = PhosphorIconDefinition;

/// Curated central registry and resolver for Phosphor tag icons.
abstract final class TagIconRegistry {
  /// Default icon fallback when a tag has no custom icon assigned.
  static const IconData defaultTagIcon = PhosphorIconsRegular.tag;

  /// Legacy ID mapping from older Material identifiers to canonical Phosphor IDs.
  static const Map<String, String> _legacyAliasMap = {
    'tag': 'tag',
    'bookmark': 'bookmark',
    'folder': 'folder',
    'key': 'key',
    'flag': 'flag',
    'pin': 'push-pin',
    'box': 'archive',
    'camera': 'camera',
    'gift': 'gift',
    'wallet': 'wallet',
    'run': 'person-simple-run',
    'fitness': 'barbell',
    'gamepad': 'game-controller',
    'music': 'music-notes',
    'movie': 'film-slate',
    'palette': 'palette',
    'hiking': 'mountains',
    'plane': 'airplane',
    'bike': 'bicycle',
    'home': 'house',
    'store': 'storefront',
    'building': 'buildings',
    'school': 'graduation-cap',
    'hotel': 'bed',
    'globe': 'globe',
    'map': 'map-pin',
    'park': 'tree',
    'star': 'star',
    'heart': 'heart',
    'bulb': 'lightbulb',
    'alert': 'warning',
    'check': 'check-circle',
    'lock': 'lock',
    'sparkles': 'sparkle',
    'sun': 'sun',
    'moon': 'moon',
    'clock': 'clock',
    'briefcase': 'briefcase',
    'chart': 'chart-bar',
    'calendar': 'calendar',
    'mail': 'envelope',
    'phone': 'phone',
    'receipt': 'receipt',
    'task': 'check-square',
    'book': 'book',
    'reading': 'book-open',
    'school_cap': 'graduation-cap',
    'pencil': 'pencil-simple',
    'library': 'books',
    'science': 'flask',
    'article': 'article',
    'computer': 'laptop',
    'code': 'code',
    'terminal': 'terminal',
    'phone_android': 'device-mobile',
    'database': 'database',
    'wifi': 'wifi-high',
    'cpu': 'cpu',
    'cloud': 'cloud',
    'bug': 'bug',
    'coffee': 'coffee',
    'restaurant': 'fork-knife',
    'shopping': 'shopping-bag',
    'pet': 'paw-print',
    'health': 'first-aid',
    'flower': 'flower',
    'car': 'car',
    'edit': 'pencil-simple',
    'search': 'magnifying-glass',
    'settings': 'gear-six',
    'trash': 'trash',
  };

  /// Normalizes and cleans an icon identifier, handling "phosphor:" prefix and legacy IDs.
  static String? cleanId(String? rawKey) {
    if (rawKey == null) return null;
    var trimmed = rawKey.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('phosphor:')) {
      trimmed = trimmed.substring('phosphor:'.length).trim();
    } else if (trimmed.startsWith('ph:')) {
      trimmed = trimmed.substring('ph:'.length).trim();
    } else if (trimmed.startsWith('icon:')) {
      trimmed = trimmed.substring('icon:'.length).trim();
    }

    trimmed = trimmed.replaceAll('_', '-');

    if (_legacyAliasMap.containsKey(trimmed)) {
      trimmed = _legacyAliasMap[trimmed]!;
    }

    return trimmed.isNotEmpty ? trimmed : null;
  }

  /// Formats an icon identifier into canonical `phosphor:<id>` storage format.
  static String formatIconKey(String id) {
    final clean = cleanId(id) ?? id.trim().toLowerCase();
    return 'phosphor:$clean';
  }

  /// Returns true if the given raw key represents a recognized custom icon.
  static bool hasCustomIcon(String? rawKey) {
    final id = cleanId(rawKey);
    if (id == null) return false;
    return kPhosphorRegularIcons.containsKey(id);
  }

  /// Resolves an icon key (e.g. "phosphor:camera", "heart", "book-open") to an IconData.
  /// If null, empty, or unknown, returns [defaultTagIcon] (PhosphorIcons.tag).
  static IconData resolveIcon(
    String? rawKey, {
    PhosphorIconWeight weight = PhosphorIconWeight.regular,
    IconData fallback = defaultTagIcon,
  }) {
    final id = cleanId(rawKey);
    if (id == null) return fallback;

    switch (weight) {
      case PhosphorIconWeight.regular:
        return kPhosphorRegularIcons[id] ?? fallback;
      case PhosphorIconWeight.light:
        return kPhosphorLightIcons[id] ?? fallback;
      case PhosphorIconWeight.bold:
        return kPhosphorBoldIcons[id] ?? fallback;
      case PhosphorIconWeight.fill:
        return kPhosphorFillIcons[id] ?? fallback;
    }
  }

  /// Resolves an icon key for backward compatibility.
  static IconData getIconData(
    String? id, {
    IconData fallback = defaultTagIcon,
    PhosphorIconWeight weight = PhosphorIconWeight.regular,
  }) {
    return resolveIcon(id, weight: weight, fallback: fallback);
  }

  /// Resolves a single PhosphorIconDefinition for an ID if available.
  static PhosphorIconDefinition? fromId(String? rawKey) {
    final id = cleanId(rawKey);
    if (id == null || !kPhosphorRegularIcons.containsKey(id)) return null;

    final glyph = kPhosphorRegularIcons[id]!;
    final name = _idToDisplayName(id);
    return PhosphorIconDefinition(
      id: id,
      name: name,
      pascalName: _idToPascal(id),
      camelName: _idToCamel(id),
      codePoint: glyph.codePoint,
    );
  }

  static String _idToDisplayName(String id) {
    return id
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _idToPascal(String id) {
    return id
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join('');
  }

  static String _idToCamel(String id) {
    final parts = id.split('-').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return id;
    final first = parts.first.toLowerCase();
    final rest = parts.skip(1).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join('');
    return '$first$rest';
  }
}
