import 'package:flutter/foundation.dart';
import '../ocr/ocr_models.dart';

/// Immutable non-destructive editing parameters for a document scan page.
///
/// Edits are stored as parameters and only applied to generate the final
/// full-resolution PDF page and OCR bitmaps when the scan is finalized.
@immutable
class ImageAdjustments {
  const ImageAdjustments({
    this.crop,
    this.rotationQuarterTurns = 0,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.grayscale = false,
  });

  /// Default neutral adjustments.
  static const neutral = ImageAdjustments();

  /// Normalized crop rectangle `[0.0, 1.0]`. If `null`, no crop is applied (full image).
  final NormalizedRect? crop;

  /// Number of 90-degree clockwise rotations `[0, 1, 2, 3]`.
  final int rotationQuarterTurns;

  /// Brightness adjustment normalized from `-1.0` (darkest) to `1.0` (brightest). Neutral is `0.0`.
  final double brightness;

  /// Contrast adjustment normalized from `-1.0` (lowest) to `1.0` (highest). Neutral is `0.0`.
  final double contrast;

  /// Saturation adjustment normalized from `-1.0` (desaturated) to `1.0` (vivid). Neutral is `0.0`.
  final double saturation;

  /// Whether image is converted to grayscale. Dedicated toggle composable with other adjustments.
  final bool grayscale;

  /// Whether all adjustment parameters are at their neutral/default state.
  bool get isNeutral =>
      (crop == null || crop == NormalizedRect.full) &&
      (rotationQuarterTurns % 4 == 0) &&
      brightness == 0.0 &&
      contrast == 0.0 &&
      saturation == 0.0 &&
      !grayscale;

  ImageAdjustments copyWith({
    NormalizedRect? crop,
    bool clearCrop = false,
    int? rotationQuarterTurns,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? grayscale,
  }) {
    return ImageAdjustments(
      crop: clearCrop ? null : (crop ?? this.crop),
      rotationQuarterTurns: (rotationQuarterTurns ?? this.rotationQuarterTurns) % 4,
      brightness: (brightness ?? this.brightness).clamp(-1.0, 1.0),
      contrast: (contrast ?? this.contrast).clamp(-1.0, 1.0),
      saturation: (saturation ?? this.saturation).clamp(-1.0, 1.0),
      grayscale: grayscale ?? this.grayscale,
    );
  }

  /// Rotates 90 degrees clockwise (↶ Rotate right).
  ImageAdjustments rotateRight() {
    return copyWith(rotationQuarterTurns: (rotationQuarterTurns + 1) % 4);
  }

  /// Rotates 90 degrees counter-clockwise (↷ Rotate left).
  ImageAdjustments rotateLeft() {
    return copyWith(rotationQuarterTurns: (rotationQuarterTurns + 3) % 4);
  }

  Map<String, dynamic> toJson() => {
        if (crop != null) 'crop': crop!.toJson(),
        'rotationQuarterTurns': rotationQuarterTurns,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'grayscale': grayscale,
      };

  factory ImageAdjustments.fromJson(Map<String, dynamic> json) {
    return ImageAdjustments(
      crop: json['crop'] != null
          ? NormalizedRect.fromJson(json['crop'] as Map<String, dynamic>)
          : null,
      rotationQuarterTurns: (json['rotationQuarterTurns'] as num?)?.toInt() ?? 0,
      brightness: ((json['brightness'] as num?)?.toDouble() ?? 0.0).clamp(-1.0, 1.0),
      contrast: ((json['contrast'] as num?)?.toDouble() ?? 0.0).clamp(-1.0, 1.0),
      saturation: ((json['saturation'] as num?)?.toDouble() ?? 0.0).clamp(-1.0, 1.0),
      grayscale: json['grayscale'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageAdjustments &&
          runtimeType == other.runtimeType &&
          crop == other.crop &&
          rotationQuarterTurns == other.rotationQuarterTurns &&
          (brightness - other.brightness).abs() < 0.001 &&
          (contrast - other.contrast).abs() < 0.001 &&
          (saturation - other.saturation).abs() < 0.001 &&
          grayscale == other.grayscale;

  @override
  int get hashCode => Object.hash(
        crop,
        rotationQuarterTurns,
        (brightness * 1000).round(),
        (contrast * 1000).round(),
        (saturation * 1000).round(),
        grayscale,
      );

  @override
  String toString() =>
      'ImageAdjustments(rot: ${rotationQuarterTurns * 90}°, br: ${brightness.toStringAsFixed(2)}, ct: ${contrast.toStringAsFixed(2)}, sat: ${saturation.toStringAsFixed(2)}, gray: $grayscale, crop: $crop)';
}
