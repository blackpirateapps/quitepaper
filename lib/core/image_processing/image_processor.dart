import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../ocr/ocr_models.dart';
import 'image_adjustments.dart';

/// Abstract contract for performing local image transformations and document normalization.
abstract class ImageProcessor {
  /// Applies non-destructive [adjustments] to [sourceBytes].
  ///
  /// If [isPreview] is `true`, downscales the processing resolution for high-performance,
  /// real-time UI slider feedback without frame drops.
  Future<Uint8List> process(
    Uint8List sourceBytes,
    ImageAdjustments adjustments, {
    bool isPreview = false,
    int maxDimension = 2048,
  });

  /// Automatically normalizes raw captured camera bytes (orientation, downscaling, contrast).
  Future<({Uint8List normalizedBytes, int width, int height, NormalizedRect suggestedCrop})>
      normalizePage(Uint8List rawBytes);

  /// Heuristically evaluates document boundary confidence score `[0.0 - 1.0]` for live camera overlays.
  double estimateDocumentConfidence(Uint8List frameBytes);
}

/// Standard image processor implemented using pure Dart `image` package.
class DartImageProcessor implements ImageProcessor {
  const DartImageProcessor();

  /// Default max dimension for high-quality PDF embedding.
  static const int defaultMaxDimension = 2048;

  /// Default max dimension for fast interactive preview slider ticks.
  static const int previewMaxDimension = 600;

  @override
  Future<Uint8List> process(
    Uint8List sourceBytes,
    ImageAdjustments adjustments, {
    bool isPreview = false,
    int maxDimension = defaultMaxDimension,
  }) async {
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;

      img.Image processed = decoded;

      // 1. If in interactive preview mode, downscale first for smooth 60fps adjustments
      if (isPreview) {
        final targetDim = previewMaxDimension;
        if (processed.width > targetDim || processed.height > targetDim) {
          if (processed.width >= processed.height) {
            processed = img.copyResize(
              processed,
              width: targetDim,
              interpolation: img.Interpolation.linear,
            );
          } else {
            processed = img.copyResize(
              processed,
              height: targetDim,
              interpolation: img.Interpolation.linear,
            );
          }
        }
      }

      // 2. Rotation (90-degree increments)
      final turns = adjustments.rotationQuarterTurns % 4;
      if (turns != 0) {
        processed = img.copyRotate(processed, angle: turns * 90);
      }

      // 3. Crop
      if (adjustments.crop != null && adjustments.crop != NormalizedRect.full) {
        final crop = adjustments.crop!;
        final cropX = (crop.x * processed.width).round().clamp(0, processed.width - 1);
        final cropY = (crop.y * processed.height).round().clamp(0, processed.height - 1);
        final cropW = (crop.width * processed.width).round().clamp(1, processed.width - cropX);
        final cropH = (crop.height * processed.height).round().clamp(1, processed.height - cropY);

        if (cropW > 10 && cropH > 10) {
          processed = img.copyCrop(
            processed,
            x: cropX,
            y: cropY,
            width: cropW,
            height: cropH,
          );
        }
      }

      // 4. Downscale final output if exceeding maxDimension
      if (!isPreview &&
          (processed.width > maxDimension || processed.height > maxDimension)) {
        if (processed.width >= processed.height) {
          processed = img.copyResize(
            processed,
            width: maxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          processed = img.copyResize(
            processed,
            height: maxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // 5. Grayscale
      if (adjustments.grayscale) {
        processed = img.grayscale(processed);
      }

      // 6. Contrast adjustment (-1.0 to 1.0 -> mapped to image library's contrast percent)
      if (adjustments.contrast != 0.0) {
        // Neutral 0.0 -> 100%, -1.0 -> 30%, 1.0 -> 170%
        final contrastFactor = ((adjustments.contrast * 70) + 100).toInt();
        processed = img.contrast(processed, contrast: contrastFactor);
      }

      // 7. Brightness & Saturation adjustment
      if (adjustments.brightness != 0.0 || adjustments.saturation != 0.0) {
        // Brightness: -1.0..1.0 -> 0.4..1.6
        final brightnessFactor = (adjustments.brightness * 0.6) + 1.0;
        // Saturation: -1.0..1.0 -> 0.0..2.0
        final saturationFactor = (adjustments.saturation + 1.0).clamp(0.0, 2.0);

        processed = img.adjustColor(
          processed,
          brightness: brightnessFactor,
          saturation: adjustments.grayscale ? 0.0 : saturationFactor,
        );
      }

      final quality = isPreview ? 75 : 85;
      return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
    } catch (e) {
      debugPrint('DartImageProcessor process error: $e');
      return sourceBytes;
    }
  }

  @override
  Future<({Uint8List normalizedBytes, int width, int height, NormalizedRect suggestedCrop})>
      normalizePage(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return (
          normalizedBytes: rawBytes,
          width: 0,
          height: 0,
          suggestedCrop: NormalizedRect.full,
        );
      }

      img.Image processed = decoded;

      // Downscale if too large
      if (processed.width > defaultMaxDimension ||
          processed.height > defaultMaxDimension) {
        if (processed.width >= processed.height) {
          processed = img.copyResize(
            processed,
            width: defaultMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          processed = img.copyResize(
            processed,
            height: defaultMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // Auto-contrast enhancement for crisp text
      processed = img.contrast(processed, contrast: 110);

      final normalizedBytes =
          Uint8List.fromList(img.encodeJpg(processed, quality: 85));

      return (
        normalizedBytes: normalizedBytes,
        width: processed.width,
        height: processed.height,
        suggestedCrop: const NormalizedRect(x: 0.03, y: 0.03, width: 0.94, height: 0.94),
      );
    } catch (e) {
      debugPrint('DartImageProcessor normalizePage error: $e');
      return (
        normalizedBytes: rawBytes,
        width: 0,
        height: 0,
        suggestedCrop: NormalizedRect.full,
      );
    }
  }

  @override
  double estimateDocumentConfidence(Uint8List frameBytes) {
    try {
      final decoded = img.decodeImage(frameBytes);
      if (decoded == null) return 0.0;

      final small = img.copyResize(decoded, width: 64, height: 64);
      final gray = img.grayscale(small);

      var totalLuminance = 0;
      final pixelCount = gray.width * gray.height;
      for (var y = 0; y < gray.height; y++) {
        for (var x = 0; x < gray.width; x++) {
          final pixel = gray.getPixel(x, y);
          totalLuminance += pixel.r.toInt();
        }
      }

      final meanLuminance = totalLuminance / pixelCount;
      if (meanLuminance < 30 || meanLuminance > 245) {
        return 0.2;
      }

      return 0.85;
    } catch (_) {
      return 0.5;
    }
  }
}
