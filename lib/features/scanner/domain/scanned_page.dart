import 'package:flutter/foundation.dart';
import '../../../core/image_processing/image_adjustments.dart';

/// A single captured page within an active document scanning session.
///
/// Preserves the unmodified original capture in [rawImageBytes] so non-destructive
/// edits in [adjustments] (crop, rotate, brightness, contrast, saturation, grayscale)
/// can be adjusted repeatedly without cumulative re-encoding quality loss.
@immutable
class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.imageBytes,
    Uint8List? rawImageBytes,
    Uint8List? previewBytes,
    Uint8List? thumbnailBytes,
    required this.width,
    required this.height,
    required this.pageNumber,
    this.adjustments = ImageAdjustments.neutral,
    this.isNormalized = false,
  })  : rawImageBytes = rawImageBytes ?? imageBytes,
        previewBytes = previewBytes ?? imageBytes,
        thumbnailBytes = thumbnailBytes ?? previewBytes ?? imageBytes;

  /// Unique identifier for this temporary page instance.
  final String id;

  /// Current display/final rendered image bytes (JPEG/PNG).
  final Uint8List imageBytes;

  /// Original unmodified capture bytes.
  final Uint8List rawImageBytes;

  /// Bounded ~600px preview representation decoded once and cached for real-time editing.
  final Uint8List previewBytes;

  /// Bounded <= 200px thumbnail representation for fast carousel rendering.
  final Uint8List thumbnailBytes;

  /// Non-destructive adjustment parameters.
  final ImageAdjustments adjustments;

  /// Pixel width of the page image.
  final int width;

  /// Pixel height of the page image.
  final int height;

  /// 1-based page sequence number.
  final int pageNumber;

  /// Whether automatic normalization has already been applied.
  final bool isNormalized;

  /// Alias for the current rendered image bytes for PDF compilation.
  Uint8List get finalImageBytes => imageBytes;

  ScannedPage copyWith({
    String? id,
    Uint8List? imageBytes,
    Uint8List? rawImageBytes,
    Uint8List? previewBytes,
    Uint8List? thumbnailBytes,
    ImageAdjustments? adjustments,
    int? width,
    int? height,
    int? pageNumber,
    bool? isNormalized,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      imageBytes: imageBytes ?? this.imageBytes,
      rawImageBytes: rawImageBytes ?? this.rawImageBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      adjustments: adjustments ?? this.adjustments,
      width: width ?? this.width,
      height: height ?? this.height,
      pageNumber: pageNumber ?? this.pageNumber,
      isNormalized: isNormalized ?? this.isNormalized,
    );
  }
}
