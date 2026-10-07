import 'dart:io';
import 'dart:typed_data';
import '../../domain/export_models.dart';

/// Signature for rasterizing a note snapshot into PNG image bytes.
typedef ImageRasterizer = Future<Uint8List> Function({
  required NoteExportSnapshot snapshot,
  required ExportRequest request,
});

/// Exporter for compiling notes into continuous, high-resolution PNG screenshot images.
class ImageExporter {
  const ImageExporter({this.rasterizer});

  /// Optional default rasterizer injected at application level.
  final ImageRasterizer? rasterizer;

  /// Compiles a note snapshot into a PNG image and writes it to [outputFile].
  Future<ExportResult> exportImage({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
    ImageRasterizer? overrideRasterizer,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final effectiveRasterizer = overrideRasterizer ?? rasterizer;
    if (effectiveRasterizer == null) {
      throw StateError(
        'No image rasterizer provided for image export. Make sure to provide a valid rasterizer.',
      );
    }

    final pngBytes = await effectiveRasterizer(
      snapshot: snapshot,
      request: request,
    );

    await outputFile.writeAsBytes(pngBytes, flush: true);

    stopwatch.stop();

    return ExportResult(
      format: ExportFormat.image,
      file: outputFile,
      filename: outputFile.uri.pathSegments.isNotEmpty
          ? outputFile.uri.pathSegments.last
          : 'note.png',
      mimeType: ExportFormat.image.mimeType,
      byteSize: pngBytes.length,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }
}
