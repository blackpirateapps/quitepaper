import 'package:flutter/material.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../../../features/tags/domain/tag_icon_registry.dart';

/// Represents an activity associated with a journal entry.
@immutable
class JournalActivity {
  const JournalActivity({
    required this.id,
    required this.label,
    required this.icon,
    this.iconKey = '',
    this.emoji,
    this.isCustom = false,
  });

  /// Normalized unique identifier (e.g. 'exercise', 'reading').
  final String id;

  /// Human-readable title (e.g. 'Exercise', 'Reading').
  final String label;

  /// Icon representing the activity.
  final IconData icon;

  /// Canonical icon identifier for serialization (e.g. 'person-simple-run', 'book-open').
  final String iconKey;

  /// Optional emoji representation.
  final String? emoji;

  /// Whether this activity was created custom by the user.
  final bool isCustom;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconKey': iconKey.isNotEmpty ? iconKey : id,
        if (emoji != null) 'emoji': emoji,
        'isCustom': isCustom,
      };

  factory JournalActivity.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final label = json['label'] as String;
    final rawIconKey = json['iconKey'] as String? ?? id;
    final resolvedIcon = TagIconRegistry.resolveIcon(
      rawIconKey,
      fallback: PhosphorIconsRegular.star,
    );

    return JournalActivity(
      id: id,
      label: label,
      icon: resolvedIcon,
      iconKey: rawIconKey,
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
      icon: PhosphorIconsRegular.personSimpleRun,
      iconKey: 'person-simple-run',
      emoji: '🏃',
    ),
    JournalActivity(
      id: 'reading',
      label: 'Reading',
      icon: PhosphorIconsRegular.bookOpen,
      iconKey: 'book-open',
      emoji: '📚',
    ),
    JournalActivity(
      id: 'work',
      label: 'Work',
      icon: PhosphorIconsRegular.laptop,
      iconKey: 'laptop',
      emoji: '💻',
    ),
    JournalActivity(
      id: 'walk',
      label: 'Walk',
      icon: PhosphorIconsRegular.personSimpleWalk,
      iconKey: 'person-simple-walk',
      emoji: '🚶',
    ),
    JournalActivity(
      id: 'cooking',
      label: 'Cooking',
      icon: PhosphorIconsRegular.cookingPot,
      iconKey: 'cooking-pot',
      emoji: '🍳',
    ),
    JournalActivity(
      id: 'music',
      label: 'Music',
      icon: PhosphorIconsRegular.musicNotes,
      iconKey: 'music-notes',
      emoji: '🎵',
    ),
    JournalActivity(
      id: 'meditation',
      label: 'Meditation',
      icon: PhosphorIconsRegular.peace,
      iconKey: 'peace',
      emoji: '🧘',
    ),
    JournalActivity(
      id: 'gaming',
      label: 'Gaming',
      icon: PhosphorIconsRegular.gameController,
      iconKey: 'game-controller',
      emoji: '🎮',
    ),
    JournalActivity(
      id: 'shopping',
      label: 'Shopping',
      icon: PhosphorIconsRegular.shoppingBag,
      iconKey: 'shopping-bag',
      emoji: '🛒',
    ),
    JournalActivity(
      id: 'movie',
      label: 'Movie',
      icon: PhosphorIconsRegular.filmSlate,
      iconKey: 'film-slate',
      emoji: '🎬',
    ),
    JournalActivity(
      id: 'rest',
      label: 'Rest',
      icon: PhosphorIconsRegular.bed,
      iconKey: 'bed',
      emoji: '😴',
    ),
    JournalActivity(
      id: 'social',
      label: 'Social',
      icon: PhosphorIconsRegular.coffee,
      iconKey: 'coffee',
      emoji: '☕',
    ),
    JournalActivity(
      id: 'family',
      label: 'Family',
      icon: PhosphorIconsRegular.house,
      iconKey: 'house',
      emoji: '🏡',
    ),
    JournalActivity(
      id: 'nature',
      label: 'Nature',
      icon: PhosphorIconsRegular.tree,
      iconKey: 'tree',
      emoji: '🌲',
    ),
    JournalActivity(
      id: 'creative',
      label: 'Creative',
      icon: PhosphorIconsRegular.palette,
      iconKey: 'palette',
      emoji: '🎨',
    ),
  ];
}
