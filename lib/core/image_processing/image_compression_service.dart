import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../../features/settings/domain/default_settings.dart';

/// Result metadata produced after image compression processing.
@immutable
class CompressedImageResult {
  const CompressedImageResult({
    required this.bytes,
    required this.originalByteSize,
    required this.compressedByteSize,
    required this.width,
    required this.height,
    required this.mimeType,
    required this.fileName,
    required this.wasCompressed,
  });

  /// The resulting image bytes (compressed if successful, or original if compression was skipped or yielded larger bytes).
  final Uint8List bytes;

  /// Byte size of the original uncompressed image.
  final int originalByteSize;

  /// Byte size of the resulting image payload.
  final int compressedByteSize;

  /// Pixel width of the resulting image.
  final int width;

  /// Pixel height of the resulting image.
  final int height;

  /// Inferred MIME type for the resulting image (e.g. `image/jpeg` or `image/png`).
  final String mimeType;

  /// Filename with appropriate extension matching the compressed format.
  final String fileName;

  /// Whether the image was actively compressed (true) or preserved as original (false).
  final bool wasCompressed;

  /// Formatted percentage of bytes saved (e.g. `82%`).
  String get savedPercentage {
    if (!wasCompressed || originalByteSize <= 0) return '0%';
    final saved = ((originalByteSize - compressedByteSize) / originalByteSize) * 100;
    return '${saved.clamp(0, 100).toStringAsFixed(0)}%';
  }
}

/// Abstract contract for local image compression and metadata probing.
abstract class ImageCompressionService {
  /// Minimum file size threshold (500 KB) below which images are not prompted or compressed.
  static const int minCompressionThresholdBytes = 500 * 1024;

  /// Evaluates whether an image size qualifies for compression dialog prompt or processing.
  bool isEligibleForCompression(int byteSize);

  /// Probes image pixel width and height without altering image bytes.
  Future<({int width, int height})> probeDimensions(Uint8List rawBytes);

  /// Compresses the image [rawBytes] using the specified [preset].
  ///
  /// Image decoding, resizing, EXIF orientation baking, and encoding are offloaded
  /// to a background isolate via [compute] to keep the UI completely smooth.
  Future<CompressedImageResult> compressImage({
    required Uint8List rawBytes,
    required String fileName,
    ImageCompressionPreset preset = ImageCompressionPreset.balanced,
    bool force = false,
  });
}

/// Parameters passed to the background isolate for image compression.
class _CompressionIsolateParams {
  const _CompressionIsolateParams({
    required this.rawBytes,
    required this.fileName,
    required this.maxDimension,
    required this.quality,
  });

  final Uint8List rawBytes;
  final String fileName;
  final int maxDimension;
  final int quality;
}

/// Default implementation of [ImageCompressionService] using pure-Dart `package:image`.
class DefaultImageCompressionService implements ImageCompressionService {
  const DefaultImageCompressionService();

  @override
  bool isEligibleForCompression(int byteSize) {
    return byteSize > ImageCompressionService.minCompressionThresholdBytes;
  }

  @override
  Future<({int width, int height})> probeDimensions(Uint8List rawBytes) async {
    try {
      final result = await compute(_probeDimensionsInIsolate, rawBytes);
      return result;
    } catch (_) {
      return (width: 0, height: 0);
    }
  }

  @override
  Future<CompressedImageResult> compressImage({
    required Uint8List rawBytes,
    required String fileName,
    ImageCompressionPreset preset = ImageCompressionPreset.balanced,
    bool force = false,
  }) async {
    // If not forced and size is at or below the 500 KB threshold, bypass compression
    if (!force && !isEligibleForCompression(rawBytes.length)) {
      final dims = await probeDimensions(rawBytes);
      return CompressedImageResult(
        bytes: rawBytes,
        originalByteSize: rawBytes.length,
        compressedByteSize: rawBytes.length,
        width: dims.width,
        height: dims.height,
        mimeType: _inferMimeType(fileName),
        fileName: fileName,
        wasCompressed: false,
      );
    }

    try {
      final result = await compute(
        _compressImageInIsolate,
        _CompressionIsolateParams(
          rawBytes: rawBytes,
          fileName: fileName,
          maxDimension: preset.maxDimension,
          quality: preset.quality,
        ),
      );
      return result;
    } catch (e) {
      debugPrint('DefaultImageCompressionService error: $e');
      final dims = await probeDimensions(rawBytes);
      return CompressedImageResult(
        bytes: rawBytes,
        originalByteSize: rawBytes.length,
        compressedByteSize: rawBytes.length,
        width: dims.width,
        height: dims.height,
        mimeType: _inferMimeType(fileName),
        fileName: fileName,
        wasCompressed: false,
      );
    }
  }

  static String _inferMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

/// Top-level isolate worker for probing dimensions.
({int width, int height}) _probeDimensionsInIsolate(Uint8List rawBytes) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return (width: 0, height: 0);
    final oriented = img.bakeOrientation(decoded);
    return (width: oriented.width, height: oriented.height);
  } catch (_) {
    return (width: 0, height: 0);
  }
}

/// Top-level isolate worker for image decoding, orientation, resizing, and encoding.
CompressedImageResult _compressImageInIsolate(_CompressionIsolateParams params) {
  try {
    final decoded = img.decodeImage(params.rawBytes);
    if (decoded == null) {
      return CompressedImageResult(
        bytes: params.rawBytes,
        originalByteSize: params.rawBytes.length,
        compressedByteSize: params.rawBytes.length,
        width: 0,
        height: 0,
        mimeType: DefaultImageCompressionService._inferMimeType(params.fileName),
        fileName: params.fileName,
        wasCompressed: false,
      );
    }

    img.Image image = img.bakeOrientation(decoded);
    final origWidth = image.width;
    final origHeight = image.height;

    // 1. Proportional downscaling if larger than max dimension
    final maxDim = params.maxDimension;
    if (image.width > maxDim || image.height > maxDim) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: maxDim,
          interpolation: img.Interpolation.linear,
        );
      } else {
        image = img.copyResize(
          image,
          height: maxDim,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 2. Encode to optimized bytes
    Uint8List encodedBytes;
    String mimeType;
    String newFileName = params.fileName;
    final ext = p.extension(params.fileName).toLowerCase();
    final nameWithoutExt = p.basenameWithoutExtension(params.fileName);

    // If source is a PNG with alpha transparency, preserve alpha using PNG
    final hasTransparency = ext == '.png' && image.hasAlpha;

    if (hasTransparency) {
      encodedBytes = Uint8List.fromList(img.encodePng(image, level: 6));
      mimeType = 'image/png';
      newFileName = '$nameWithoutExt.png';
    } else {
      encodedBytes = Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
      mimeType = 'image/jpeg';
      newFileName = '$nameWithoutExt.jpg';
    }

    // 3. Safeguard: if compressed output is actually larger than original, keep original
    if (encodedBytes.length >= params.rawBytes.length) {
      return CompressedImageResult(
        bytes: params.rawBytes,
        originalByteSize: params.rawBytes.length,
        compressedByteSize: params.rawBytes.length,
        width: origWidth,
        height: origHeight,
        mimeType: DefaultImageCompressionService._inferMimeType(params.fileName),
        fileName: params.fileName,
        wasCompressed: false,
      );
    }

    return CompressedImageResult(
      bytes: encodedBytes,
      originalByteSize: params.rawBytes.length,
      compressedByteSize: encodedBytes.length,
      width: image.width,
      height: image.height,
      mimeType: mimeType,
      fileName: newFileName,
      wasCompressed: true,
    );
  } catch (e) {
    debugPrint('_compressImageInIsolate error: $e');
    return CompressedImageResult(
      bytes: params.rawBytes,
      originalByteSize: params.rawBytes.length,
      compressedByteSize: params.rawBytes.length,
      width: 0,
      height: 0,
      mimeType: DefaultImageCompressionService._inferMimeType(params.fileName),
      fileName: params.fileName,
      wasCompressed: false,
    );
  }
}

/// Riverpod provider for accessing [ImageCompressionService].
final imageCompressionServiceProvider = Provider<ImageCompressionService>((ref) {
  return const DefaultImageCompressionService();
});
