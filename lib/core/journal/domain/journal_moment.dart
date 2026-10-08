import 'package:flutter/material.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';

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

  /// Phosphor icon for editorial UI.
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
      icon: PhosphorIconsRegular.coffee,
      emoji: '☕',
      description: 'Daily routines, calm quiet days',
    ),
    JournalMoment(
      key: 'travel',
      label: 'Travel',
      icon: PhosphorIconsRegular.airplane,
      emoji: '✈️',
      description: 'Trips, exploration, transit',
    ),
    JournalMoment(
      key: 'work',
      label: 'Work',
      icon: PhosphorIconsRegular.briefcase,
      emoji: '💼',
      description: 'Career, projects, study',
    ),
    JournalMoment(
      key: 'family',
      label: 'Family',
      icon: PhosphorIconsRegular.house,
      emoji: '🏡',
      description: 'Quality family time, home life',
    ),
    JournalMoment(
      key: 'social',
      label: 'Social',
      icon: PhosphorIconsRegular.chatsTeardrop,
      emoji: '👥',
      description: 'Friends, gatherings, community',
    ),
    JournalMoment(
      key: 'health',
      label: 'Health',
      icon: PhosphorIconsRegular.heart,
      emoji: '🌿',
      description: 'Wellness, recovery, fitness',
    ),
    JournalMoment(
      key: 'creative',
      label: 'Creative',
      icon: PhosphorIconsRegular.palette,
      emoji: '🎨',
      description: 'Art, writing, building, music',
    ),
    JournalMoment(
      key: 'celebration',
      label: 'Celebration',
      icon: PhosphorIconsRegular.confetti,
      emoji: '🎉',
      description: 'Milestones, birthdays, wins',
    ),
    JournalMoment(
      key: 'difficult',
      label: 'Difficult',
      icon: PhosphorIconsRegular.cloudRain,
      emoji: '🌧️',
      description: 'Challenges, grief, obstacles',
    ),
    JournalMoment(
      key: 'reflection',
      label: 'Reflection',
      icon: PhosphorIconsRegular.sparkle,
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
