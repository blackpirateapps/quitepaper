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

  /// Document preset with auto contrast enhancement and subtle brightness boost.
  static const auto = ImageAdjustments(
    contrast: 0.20,
    brightness: 0.05,
  );

  /// Document preset for crisp black & white / monochrome rendering.
  static const blackAndWhite = ImageAdjustments(
    grayscale: true,
    contrast: 0.25,
    brightness: 0.10,
  );

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

  /// Generates a 4x5 20-element ColorFilter matrix applying saturation, grayscale,
  /// contrast, and brightness on the GPU in real-time with zero image re-encoding.
  List<double> toColorMatrix() {
    if (isNeutral) {
      return const <double>[
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ];
    }

    // 1. Saturation & Grayscale (Rec. 709 luminance coefficients)
    const rLum = 0.2126;
    const gLum = 0.7152;
    const bLum = 0.0722;

    final s = grayscale ? 0.0 : (saturation + 1.0).clamp(0.0, 2.0);
    final invS = 1.0 - s;

    final mSat00 = invS * rLum + s;
    final mSat01 = invS * gLum;
    final mSat02 = invS * bLum;

    final mSat10 = invS * rLum;
    final mSat11 = invS * gLum + s;
    final mSat12 = invS * bLum;

    final mSat20 = invS * rLum;
    final mSat21 = invS * gLum;
    final mSat22 = invS * bLum + s;

    // 2. Contrast Factor C
    final cFactor = contrast >= 0.0 ? (1.0 + contrast * 1.5) : (1.0 + contrast * 0.7);

    // 3. Brightness and Contrast Offset
    // Contrast midpoint is 128 in [0, 255]. Offset = 128 * (1 - C) + (brightness * 128)
    final offset = 128.0 * (1.0 - cFactor) + (brightness * 128.0);

    return <double>[
      cFactor * mSat00, cFactor * mSat01, cFactor * mSat02, 0.0, offset,
      cFactor * mSat10, cFactor * mSat11, cFactor * mSat12, 0.0, offset,
      cFactor * mSat20, cFactor * mSat21, cFactor * mSat22, 0.0, offset,
      0.0,              0.0,              0.0,              1.0, 0.0,
    ];
  }

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
