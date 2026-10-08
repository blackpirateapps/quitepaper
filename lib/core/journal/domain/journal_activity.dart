import 'package:flutter/material.dart';

/// Represents an activity associated with a journal entry.
@immutable
class JournalActivity {
  const JournalActivity({
    required this.id,
    required this.label,
    required this.icon,
    this.emoji,
    this.isCustom = false,
  });

  /// Normalized unique identifier (e.g. 'exercise', 'reading').
  final String id;

  /// Human-readable title (e.g. 'Exercise', 'Reading').
  final String label;

  /// Icon representing the activity.
  final IconData icon;

  /// Optional emoji representation.
  final String? emoji;

  /// Whether this activity was created custom by the user.
  final bool isCustom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
        if (emoji != null) 'emoji': emoji,
        'isCustom': isCustom,
      };

  factory JournalActivity.fromJson(Map<String, dynamic> json) {
    final codePoint = json['iconCodePoint'] as int? ?? Icons.star_border_rounded.codePoint;
    final fontFamily = json['iconFontFamily'] as String?;
    final fontPackage = json['iconFontPackage'] as String?;

    return JournalActivity(
      id: json['id'] as String,
      label: json['label'] as String,
      // ignore: non_const_argument_for_const_parameter
      icon: IconData(codePoint, fontFamily: fontFamily, fontPackage: fontPackage),
      emoji: json['emoji'] as String?,
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalActivity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'JournalActivity($id, $label)';

  static const List<JournalActivity> standardPresets = [
    JournalActivity(
      id: 'exercise',
      label: 'Exercise',
      icon: Icons.directions_run_rounded,
      emoji: '🏃',
    ),
    JournalActivity(
      id: 'reading',
      label: 'Reading',
      icon: Icons.menu_book_rounded,
      emoji: '📚',
    ),
    JournalActivity(
      id: 'work',
      label: 'Work',
      icon: Icons.laptop_chromebook_rounded,
      emoji: '💻',
    ),
    JournalActivity(
      id: 'walk',
      label: 'Walk',
      icon: Icons.directions_walk_rounded,
      emoji: '🚶',
    ),
    JournalActivity(
      id: 'cooking',
      label: 'Cooking',
      icon: Icons.restaurant_rounded,
      emoji: '🍳',
    ),
    JournalActivity(
      id: 'music',
      label: 'Music',
      icon: Icons.music_note_rounded,
      emoji: '🎵',
    ),
    JournalActivity(
      id: 'meditation',
      label: 'Meditation',
      icon: Icons.self_improvement_rounded,
      emoji: '🧘',
    ),
    JournalActivity(
      id: 'gaming',
      label: 'Gaming',
      icon: Icons.sports_esports_rounded,
      emoji: '🎮',
    ),
    JournalActivity(
      id: 'shopping',
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      emoji: '🛒',
    ),
    JournalActivity(
      id: 'movie',
      label: 'Movie',
      icon: Icons.movie_outlined,
      emoji: '🎬',
    ),
    JournalActivity(
      id: 'rest',
      label: 'Rest',
      icon: Icons.bedtime_outlined,
      emoji: '😴',
    ),
    JournalActivity(
      id: 'social',
      label: 'Social',
      icon: Icons.local_cafe_outlined,
      emoji: '☕',
    ),
    JournalActivity(
      id: 'family',
      label: 'Family',
      icon: Icons.home_outlined,
      emoji: '🏡',
    ),
    JournalActivity(
      id: 'nature',
      label: 'Nature',
      icon: Icons.forest_outlined,
      emoji: '🌲',
    ),
    JournalActivity(
      id: 'creative',
      label: 'Creative',
      icon: Icons.palette_outlined,
      emoji: '🎨',
    ),
  ];
}
