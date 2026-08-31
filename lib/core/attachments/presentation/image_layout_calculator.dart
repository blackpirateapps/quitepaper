import 'package:flutter/material.dart';

/// Pure, deterministic layout calculator for note-body images.
///
/// Implements Quiet Paper's editorial media sizing philosophy:
/// 1. Aspect ratio is ALWAYS preserved. Proportional fitting only.
/// 2. Small images must NOT be unnecessarily upscaled beyond their intrinsic width.
/// 3. Large images scale down to available content width.
/// 4. Tall images (screenshots, infographics) are constrained by viewport-aware maximum height.
/// 5. Never distorts or crops images.
abstract final class ImageLayoutCalculator {
  /// Default maximum allowed height for inline images in logical pixels.
  static const double defaultMaxAllowedHeight = 520.0;

  /// Absolute minimum dimension for an image widget.
  static const double minImageDimension = 24.0;

  /// Calculates presentation dimensions for an inline note image.
  static Size calculateSize({
    required double? intrinsicWidth,
    required double? intrinsicHeight,
    required double availableContentWidth,
    double maxAllowedHeight = defaultMaxAllowedHeight,
  }) {
    if (availableContentWidth <= 0) {
      return const Size(minImageDimension, minImageDimension);
    }

    // 1. If intrinsic dimensions are known and valid:
    if (intrinsicWidth != null &&
        intrinsicHeight != null &&
        intrinsicWidth > 0 &&
        intrinsicHeight > 0) {
      final aspectRatio = intrinsicWidth / intrinsicHeight;

      // Small images are not upscaled; large images scale down to content width
      var displayWidth = intrinsicWidth < availableContentWidth
          ? intrinsicWidth
          : availableContentWidth;
      var displayHeight = displayWidth / aspectRatio;

      // Unusually tall images are constrained by maxAllowedHeight while scaling width proportionally
      if (maxAllowedHeight > 0 && displayHeight > maxAllowedHeight) {
        displayHeight = maxAllowedHeight;
        displayWidth = displayHeight * aspectRatio;
      }

      // Enforce bounds
      displayWidth = displayWidth.clamp(minImageDimension, availableContentWidth);
      displayHeight = displayHeight.clamp(minImageDimension, double.infinity);

      return Size(displayWidth, displayHeight);
    }

    // 2. Fallback placeholder sizing when dimensions are not yet known
    final fallbackHeight = (availableContentWidth * 0.5625).clamp(120.0, maxAllowedHeight);
    return Size(availableContentWidth, fallbackHeight);
  }
}
