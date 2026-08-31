import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../ocr/ocr_models.dart';
import 'image_adjustments.dart';

/// Representation payloads produced when a captured document page is decoded once.
typedef PageRepresentations = ({
  Uint8List previewBytes,
  Uint8List thumbnailBytes,
  int width,
  int height,
});

/// Abstract contract for performing local image transformations and document normalization.
abstract class ImageProcessor {
  /// Decodes raw camera/import image bytes once and extracts bounded preview (~600px)
  /// and thumbnail (<=200px) representations to cache for fast, zero-lag editing.
  Future<PageRepresentations> createPageRepresentations(Uint8List rawBytes);

  /// Applies non-destructive [adjustments] to [sourceBytes].
  ///
  /// If [isPreview] is `true`, downscales the processing resolution for high-performance
  /// preview feedback.
  Future<Uint8List> process(
    Uint8List sourceBytes,
    ImageAdjustments adjustments, {
    bool isPreview = false,
    int maxDimension = 2048,
  });

  /// Processes high-resolution capture bytes applying final crop, rotation, tone adjustments,
  /// and max dimension bounding for final PDF document embedding.
  Future<({Uint8List imageBytes, int width, int height})> processHighResolution(
    Uint8List rawBytes,
    ImageAdjustments adjustments, {
    int maxDimension = 2048,
  });

  /// Automatically normalizes raw captured camera bytes (orientation, downscaling, contrast).
  Future<({Uint8List normalizedBytes, int width, int height, NormalizedRect suggestedCrop})>
      normalizePage(Uint8List rawBytes);

  /// Pre-processes and enhances an image bitmap specifically for Optical Character Recognition.
  Future<Uint8List> enhanceForOcr(Uint8List rawBytes);

  /// Heuristically evaluates document boundary confidence score `[0.0 - 1.0]` for live camera overlays.
  double estimateDocumentConfidence(Uint8List frameBytes);
}

/// Helper payload for background isolate processing.
class _HighResProcessingParams {
  const _HighResProcessingParams({
    required this.rawBytes,
    required this.adjustments,
    required this.maxDimension,
  });

  final Uint8List rawBytes;
  final ImageAdjustments adjustments;
  final int maxDimension;
}

/// Standard image processor implemented using pure Dart `image` package.
class DartImageProcessor implements ImageProcessor {
  const DartImageProcessor();

  /// Default max dimension for high-quality PDF embedding.
  static const int defaultMaxDimension = 2048;

  /// Default max dimension for fast interactive preview slider ticks.
  static const int previewMaxDimension = 600;

  /// Default max dimension for lightweight thumbnail carousel items.
  static const int thumbnailMaxDimension = 200;

  @override
  Future<PageRepresentations> createPageRepresentations(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return (
          previewBytes: rawBytes,
          thumbnailBytes: rawBytes,
          width: 0,
          height: 0,
        );
      }

      final oriented = img.bakeOrientation(decoded);
      final origWidth = oriented.width;
      final origHeight = oriented.height;

      // 1. Create ~600px preview representation
      img.Image previewImg = oriented;
      if (previewImg.width > previewMaxDimension || previewImg.height > previewMaxDimension) {
        if (previewImg.width >= previewImg.height) {
          previewImg = img.copyResize(
            previewImg,
            width: previewMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          previewImg = img.copyResize(
            previewImg,
            height: previewMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }
      final previewBytes = Uint8List.fromList(img.encodeJpg(previewImg, quality: 78));

      // 2. Create <= 200px thumbnail representation
      img.Image thumbImg = previewImg;
      if (thumbImg.width > thumbnailMaxDimension || thumbImg.height > thumbnailMaxDimension) {
        if (thumbImg.width >= thumbImg.height) {
          thumbImg = img.copyResize(
            thumbImg,
            width: thumbnailMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          thumbImg = img.copyResize(
            thumbImg,
            height: thumbnailMaxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }
      final thumbnailBytes = Uint8List.fromList(img.encodeJpg(thumbImg, quality: 70));

      return (
        previewBytes: previewBytes,
        thumbnailBytes: thumbnailBytes,
        width: origWidth,
        height: origHeight,
      );
    } catch (e) {
      debugPrint('createPageRepresentations error: $e');
      return (
        previewBytes: rawBytes,
        thumbnailBytes: rawBytes,
        width: 0,
        height: 0,
      );
    }
  }

  @override
  Future<({Uint8List imageBytes, int width, int height})> processHighResolution(
    Uint8List rawBytes,
    ImageAdjustments adjustments, {
    int maxDimension = defaultMaxDimension,
  }) async {
    // If neutral, return raw bytes with basic orientation and dimension check
    if (adjustments.isNeutral) {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        return (imageBytes: rawBytes, width: 0, height: 0);
      }
      final oriented = img.bakeOrientation(decoded);
      if (oriented.width <= maxDimension && oriented.height <= maxDimension) {
        return (
          imageBytes: rawBytes,
          width: oriented.width,
          height: oriented.height,
        );
      }
    }

    try {
      final result = await compute(
        _executeHighResProcessing,
        _HighResProcessingParams(
          rawBytes: rawBytes,
          adjustments: adjustments,
          maxDimension: maxDimension,
        ),
      );
      return result;
    } catch (e) {
      debugPrint('processHighResolution compute fallback: $e');
      return _executeHighResProcessing(
        _HighResProcessingParams(
          rawBytes: rawBytes,
          adjustments: adjustments,
          maxDimension: maxDimension,
        ),
      );
    }
  }

  static ({Uint8List imageBytes, int width, int height}) _executeHighResProcessing(
    _HighResProcessingParams params,
  ) {
    try {
      final decoded = img.decodeImage(params.rawBytes);
      if (decoded == null) {
        return (imageBytes: params.rawBytes, width: 0, height: 0);
      }

      img.Image processed = img.bakeOrientation(decoded);

      // 1. Rotation
      final turns = params.adjustments.rotationQuarterTurns % 4;
      if (turns != 0) {
        processed = img.copyRotate(processed, angle: turns * 90);
      }

      // 2. High-Resolution Crop
      if (params.adjustments.crop != null && params.adjustments.crop != NormalizedRect.full) {
        final crop = params.adjustments.crop!;
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

      // 3. Downscale if exceeding maxDimension
      if (processed.width > params.maxDimension || processed.height > params.maxDimension) {
        if (processed.width >= processed.height) {
          processed = img.copyResize(
            processed,
            width: params.maxDimension,
            interpolation: img.Interpolation.linear,
          );
        } else {
          processed = img.copyResize(
            processed,
            height: params.maxDimension,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // 4. Grayscale
      if (params.adjustments.grayscale) {
        processed = img.grayscale(processed);
      }

      // 5. Contrast
      if (params.adjustments.contrast != 0.0) {
        final contrastFactor = ((params.adjustments.contrast * 70) + 100).toInt();
        processed = img.contrast(processed, contrast: contrastFactor);
      }

      // 6. Brightness & Saturation
      if (params.adjustments.brightness != 0.0 || params.adjustments.saturation != 0.0) {
        final brightnessFactor = (params.adjustments.brightness * 0.6) + 1.0;
        final saturationFactor = (params.adjustments.saturation + 1.0).clamp(0.0, 2.0);

        processed = img.adjustColor(
          processed,
          brightness: brightnessFactor,
          saturation: params.adjustments.grayscale ? 0.0 : saturationFactor,
        );
      }

      final encoded = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
      return (
        imageBytes: encoded,
        width: processed.width,
        height: processed.height,
      );
    } catch (e) {
      debugPrint('_executeHighResProcessing error: $e');
      return (imageBytes: params.rawBytes, width: 0, height: 0);
    }
  }

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

      img.Image processed = img.bakeOrientation(decoded);

      // 1. If in interactive preview mode, downscale first
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

      // 2. Rotation
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

      // 6. Contrast adjustment
      if (adjustments.contrast != 0.0) {
        final contrastFactor = ((adjustments.contrast * 70) + 100).toInt();
        processed = img.contrast(processed, contrast: contrastFactor);
      }

      // 7. Brightness & Saturation adjustment
      if (adjustments.brightness != 0.0 || adjustments.saturation != 0.0) {
        final brightnessFactor = (adjustments.brightness * 0.6) + 1.0;
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
  Future<Uint8List> enhanceForOcr(Uint8List rawBytes) async {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      img.Image processed = img.bakeOrientation(decoded);

      // Contrast enhancement for clear character edges
      processed = img.contrast(processed, contrast: 115);

      return Uint8List.fromList(img.encodePng(processed));
    } catch (e) {
      debugPrint('DartImageProcessor enhanceForOcr error: $e');
      return rawBytes;
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

      img.Image processed = img.bakeOrientation(decoded);

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
