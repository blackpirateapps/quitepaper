import 'package:flutter/foundation.dart';

/// Immutable model representing default preferences and gesture toggles.
@immutable
class DefaultSettings {
  const DefaultSettings({
    this.swipeToSearchEditor = true,
    this.swipeDownToSearchNotes = true,
    this.interactiveChecklistsInPreview = true,
  });

  /// Whether pulling/swiping down at the top of an open note reveals the in-note search bar.
  final bool swipeToSearchEditor;

  /// Whether pulling down past threshold at the top of the notes list opens global search.
  final bool swipeDownToSearchNotes;

  /// Whether checklist items in markdown preview mode can be clicked to toggle done/undone.
  final bool interactiveChecklistsInPreview;

  DefaultSettings copyWith({
    bool? swipeToSearchEditor,
    bool? swipeDownToSearchNotes,
    bool? interactiveChecklistsInPreview,
  }) {
    return DefaultSettings(
      swipeToSearchEditor: swipeToSearchEditor ?? this.swipeToSearchEditor,
      swipeDownToSearchNotes:
          swipeDownToSearchNotes ?? this.swipeDownToSearchNotes,
      interactiveChecklistsInPreview:
          interactiveChecklistsInPreview ?? this.interactiveChecklistsInPreview,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultSettings &&
          runtimeType == other.runtimeType &&
          swipeToSearchEditor == other.swipeToSearchEditor &&
          swipeDownToSearchNotes == other.swipeDownToSearchNotes &&
          interactiveChecklistsInPreview == other.interactiveChecklistsInPreview;

  @override
  int get hashCode => Object.hash(
        swipeToSearchEditor,
        swipeDownToSearchNotes,
        interactiveChecklistsInPreview,
      );
}
