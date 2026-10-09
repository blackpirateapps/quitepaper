import 'package:flutter/foundation.dart';

/// Strategy for handling image attachments on import.
enum ImageCompressionAction {
  /// Prompt the user with a dialog if image exceeds size threshold.
  ask('ask', 'Ask every time'),

  /// Automatically compress images exceeding size threshold.
  alwaysCompress('always_compress', 'Always compress'),

  /// Keep images at original resolution and file size.
  keepOriginal('keep_original', 'Keep original');

  const ImageCompressionAction(this.identifier, this.label);
  final String identifier;
  final String label;

  static ImageCompressionAction fromIdentifier(String? id) {
    if (id == null) return ImageCompressionAction.ask;
    for (final action in ImageCompressionAction.values) {
      if (action.identifier == id) return action;
    }
    return ImageCompressionAction.ask;
  }
}

/// Compression preset defining resolution limit and compression quality.
enum ImageCompressionPreset {
  /// 1920px max dimension, 80% JPEG quality.
  balanced(
    identifier: 'balanced',
    label: 'Balanced',
    description: '1920px max, 80% quality (Recommended)',
    maxDimension: 1920,
    quality: 80,
  ),

  /// 2560px max dimension, 85% JPEG quality.
  highQuality(
    identifier: 'high_quality',
    label: 'High Quality',
    description: '2560px max, 85% quality',
    maxDimension: 2560,
    quality: 85,
  ),

  /// 1280px max dimension, 70% JPEG quality.
  compact(
    identifier: 'compact',
    label: 'Compact',
    description: '1280px max, 70% quality',
    maxDimension: 1280,
    quality: 70,
  );

  const ImageCompressionPreset({
    required this.identifier,
    required this.label,
    required this.description,
    required this.maxDimension,
    required this.quality,
  });

  final String identifier;
  final String label;
  final String description;
  final int maxDimension;
  final int quality;

  static ImageCompressionPreset fromIdentifier(String? id) {
    if (id == null) return ImageCompressionPreset.balanced;
    for (final preset in ImageCompressionPreset.values) {
      if (preset.identifier == id) return preset;
    }
    return ImageCompressionPreset.balanced;
  }
}

/// Immutable model representing default preferences and gesture toggles.
@immutable
class DefaultSettings {
  const DefaultSettings({
    this.swipeToSearchEditor = true,
    this.swipeDownToSearchNotes = true,
    this.interactiveChecklistsInPreview = true,
    this.imageCompressionAction = ImageCompressionAction.ask,
    this.imageCompressionPreset = ImageCompressionPreset.balanced,
    this.showPlaceAndWeatherOnEntries = true,
    this.suggestPlaceForPastEntries = true,
  });

  /// Whether pulling/swiping down at the top of an open note reveals the in-note search bar.
  final bool swipeToSearchEditor;

  /// Whether pulling down past threshold at the top of the notes list opens global search.
  final bool swipeDownToSearchNotes;

  /// Whether checklist items in markdown preview mode can be clicked to toggle done/undone.
  final bool interactiveChecklistsInPreview;

  /// Default action to take when attaching an image larger than 500 KB.
  final ImageCompressionAction imageCompressionAction;

  /// Resolution and quality preset used when compressing images.
  final ImageCompressionPreset imageCompressionPreset;

  /// Whether the quiet place/weather dateline is shown on journal timeline entries.
  final bool showPlaceAndWeatherOnEntries;

  /// Whether to nudge the user to add a place to past journal entries that have none.
  /// This is the master switch flipped off by the nudge's "Don't ask again" action.
  final bool suggestPlaceForPastEntries;

  DefaultSettings copyWith({
    bool? swipeToSearchEditor,
    bool? swipeDownToSearchNotes,
    bool? interactiveChecklistsInPreview,
    ImageCompressionAction? imageCompressionAction,
    ImageCompressionPreset? imageCompressionPreset,
    bool? showPlaceAndWeatherOnEntries,
    bool? suggestPlaceForPastEntries,
  }) {
    return DefaultSettings(
      swipeToSearchEditor: swipeToSearchEditor ?? this.swipeToSearchEditor,
      swipeDownToSearchNotes:
          swipeDownToSearchNotes ?? this.swipeDownToSearchNotes,
      interactiveChecklistsInPreview:
          interactiveChecklistsInPreview ?? this.interactiveChecklistsInPreview,
      imageCompressionAction:
          imageCompressionAction ?? this.imageCompressionAction,
      imageCompressionPreset:
          imageCompressionPreset ?? this.imageCompressionPreset,
      showPlaceAndWeatherOnEntries:
          showPlaceAndWeatherOnEntries ?? this.showPlaceAndWeatherOnEntries,
      suggestPlaceForPastEntries:
          suggestPlaceForPastEntries ?? this.suggestPlaceForPastEntries,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultSettings &&
          runtimeType == other.runtimeType &&
          swipeToSearchEditor == other.swipeToSearchEditor &&
          swipeDownToSearchNotes == other.swipeDownToSearchNotes &&
          interactiveChecklistsInPreview ==
              other.interactiveChecklistsInPreview &&
          imageCompressionAction == other.imageCompressionAction &&
          imageCompressionPreset == other.imageCompressionPreset &&
          showPlaceAndWeatherOnEntries == other.showPlaceAndWeatherOnEntries &&
          suggestPlaceForPastEntries == other.suggestPlaceForPastEntries;

  @override
  int get hashCode => Object.hash(
        swipeToSearchEditor,
        swipeDownToSearchNotes,
        interactiveChecklistsInPreview,
        imageCompressionAction,
        imageCompressionPreset,
        showPlaceAndWeatherOnEntries,
        suggestPlaceForPastEntries,
      );
}
