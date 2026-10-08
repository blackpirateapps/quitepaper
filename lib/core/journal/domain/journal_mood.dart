import 'package:flutter/foundation.dart';

/// Represents a 10-level visual mood scale for journal entries.
@immutable
class JournalMood {
  const JournalMood({
    required this.level,
    required this.emoji,
    required this.label,
  });

  /// Numeric mood level strictly between 1 and 10.
  final int level;

  /// Expressive emoji/icon representing this mood.
  final String emoji;

  /// Human-readable label for this mood level.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JournalMood &&
          runtimeType == other.runtimeType &&
          level == other.level;

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() => 'JournalMood($level: $emoji $label)';

  static const List<JournalMood> levels = [
    JournalMood(level: 1, emoji: '😭', label: 'Terrible'),
    JournalMood(level: 2, emoji: '😢', label: 'Very Bad'),
    JournalMood(level: 3, emoji: '😞', label: 'Bad'),
    JournalMood(level: 4, emoji: '🙁', label: 'Subdued'),
    JournalMood(level: 5, emoji: '😐', label: 'Neutral'),
    JournalMood(level: 6, emoji: '🙂', label: 'Pleasant'),
    JournalMood(level: 7, emoji: '😊', label: 'Good'),
    JournalMood(level: 8, emoji: '😁', label: 'Great'),
    JournalMood(level: 9, emoji: '🥳', label: 'Celebratory'),
    JournalMood(level: 10, emoji: '🤩', label: 'Ecstatic'),
  ];

  /// Resolves a [JournalMood] from an integer level (1..10) or string.
  static JournalMood? fromLevel(dynamic value) {
    if (value == null) return null;
    int? parsed;
    if (value is int) {
      parsed = value;
    } else if (value is String) {
      parsed = int.tryParse(value.trim());
    }
    if (parsed == null || parsed < 1 || parsed > 10) return null;
    return levels[parsed - 1];
  }
}
