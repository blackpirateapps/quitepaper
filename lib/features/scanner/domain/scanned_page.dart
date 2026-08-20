import 'package:flutter/foundation.dart';

/// A single captured page within an active document scanning session.
@immutable
class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.pageNumber,
    this.isNormalized = false,
  });

  /// Unique identifier for this temporary page instance
  final String id;

  /// Raw or normalized image bytes (JPEG/PNG)
  final Uint8List imageBytes;

  /// Pixel width of the page image
  final int width;

  /// Pixel height of the page image
  final int height;

  /// 1-based page sequence number
  final int pageNumber;

  /// Whether automatic normalization has already been applied
  final bool isNormalized;

  ScannedPage copyWith({
    String? id,
    Uint8List? imageBytes,
    int? width,
    int? height,
    int? pageNumber,
    bool? isNormalized,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      imageBytes: imageBytes ?? this.imageBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      pageNumber: pageNumber ?? this.pageNumber,
      isNormalized: isNormalized ?? this.isNormalized,
    );
  }
}
