import 'package:flutter/material.dart';

/// Represents a curated moment category for a journal entry.
@immutable
class JournalMoment {
  const JournalMoment({
    required this.key,
    required this.label,
    required this.icon,
    required this.emoji,
    required this.description,
  });

  /// Normalized canonical identifier (e.g. 'ordinary', 'travel').
  final String key;

  /// Human-readable title (e.g. 'Ordinary', 'Travel').
  final String label;

  /// Material icon for editorial UI.
  final IconData icon;

  /// Emoji representation.
  final String emoji;

  /// Brief description of this moment category.
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalMoment &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'JournalMoment($key, $label)';

  static const List<JournalMoment> all = [
    JournalMoment(
      key: 'ordinary',
      label: 'Ordinary',
      icon: Icons.coffee_rounded,
      emoji: '☕',
      description: 'Daily routines, calm quiet days',
    ),
    JournalMoment(
      key: 'travel',
      label: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      emoji: '✈️',
      description: 'Trips, exploration, transit',
    ),
    JournalMoment(
      key: 'work',
      label: 'Work',
      icon: Icons.work_outline_rounded,
      emoji: '💼',
      description: 'Career, projects, study',
    ),
    JournalMoment(
      key: 'family',
      label: 'Family',
      icon: Icons.home_outlined,
      emoji: '🏡',
      description: 'Quality family time, home life',
    ),
    JournalMoment(
      key: 'social',
      label: 'Social',
      icon: Icons.people_outline_rounded,
      emoji: '👥',
      description: 'Friends, gatherings, community',
    ),
    JournalMoment(
      key: 'health',
      label: 'Health',
      icon: Icons.spa_outlined,
      emoji: '🌿',
      description: 'Wellness, recovery, fitness',
    ),
    JournalMoment(
      key: 'creative',
      label: 'Creative',
      icon: Icons.palette_outlined,
      emoji: '🎨',
      description: 'Art, writing, building, music',
    ),
    JournalMoment(
      key: 'celebration',
      label: 'Celebration',
      icon: Icons.celebration_outlined,
      emoji: '🎉',
      description: 'Milestones, birthdays, wins',
    ),
    JournalMoment(
      key: 'difficult',
      label: 'Difficult',
      icon: Icons.thunderstorm_outlined,
      emoji: '🌧️',
      description: 'Challenges, grief, obstacles',
    ),
    JournalMoment(
      key: 'reflection',
      label: 'Reflection',
      icon: Icons.auto_stories_outlined,
      emoji: '🕯️',
      description: 'Journaling, philosophy, clarity',
    ),
  ];

  /// Resolves a [JournalMoment] from a raw key string.
  static JournalMoment? fromKey(String? key) {
    if (key == null) return null;
    final normalized = key.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    for (final m in all) {
      if (m.key == normalized) return m;
    }
    return null;
  }
}
