import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

/// Bounds PDF raster work for documents whose declared page size is unusually
/// large. PDF dimensions are expressed in points (72 points per inch).
class PdfRasterPolicy {
  const PdfRasterPolicy._();

  static const int maxPixelsPerPage = 4 * 1024 * 1024;
  static const double maxOcrDpi = 150;

  /// Reads page MediaBox dimensions from ordinary, uncompressed PDF page
  /// dictionaries. Returns null when dimensions cannot be safely determined.
  static List<({double width, double height})> pageSizes(Uint8List bytes) {
    final source = String.fromCharCodes(bytes);
    final regex = RegExp(
      r'/Type\s*/Page\b(?:(?!endobj)[\s\S])*?/MediaBox\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]',
    );
    return regex
        .allMatches(source)
        .map((match) {
          final x1 = double.parse(match.group(1)!);
          final y1 = double.parse(match.group(2)!);
          final x2 = double.parse(match.group(3)!);
          final y2 = double.parse(match.group(4)!);
          return (width: (x2 - x1).abs(), height: (y2 - y1).abs());
        })
        .where((size) => size.width > 0 && size.height > 0)
        .toList();
  }

  static double safeDpi(Uint8List bytes, double requestedDpi) {
    var dpi = requestedDpi;
    for (final size in pageSizes(bytes)) {
      final requestedPixels = size.width * size.height * dpi * dpi / (72 * 72);
      if (requestedPixels > maxPixelsPerPage) {
        dpi = dpi * math.sqrt(maxPixelsPerPage / requestedPixels);
      }
    }
    return dpi;
  }

  static bool shouldSkipOcr(Uint8List bytes) {
    const maxOcrPdfBytes = 8 * 1024 * 1024;
    if (bytes.length > maxOcrPdfBytes) return true;
    final sizes = pageSizes(bytes);
    if (sizes.isEmpty) return false;
    return sizes.any(
      (size) =>
          size.width * size.height * maxOcrDpi * maxOcrDpi / (72 * 72) >
          maxPixelsPerPage,
    );
  }
}

/// Single rendered PDF page image representation.
@immutable
class RenderedPage {
  const RenderedPage({
    required this.pageNumber,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  /// 1-based page sequence number.
  final int pageNumber;

  /// Rendered raster image bytes (PNG).
  final Uint8List imageBytes;

  /// Pixel width of rendered bitmap.
  final int width;

  /// Pixel height of rendered bitmap.
  final int height;
}

/// Abstract contract for rasterizing PDF pages for on-device OCR or viewer display.
abstract class PdfPageRenderer {
  /// Renders all or specified [pageIndices] of a PDF at target [dpi].
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  });

  /// Renders a single page by 0-based index.
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  });
}

/// Default PDF page renderer using Flutter `printing` raster engine.
class DefaultPdfPageRenderer implements PdfPageRenderer {
  const DefaultPdfPageRenderer();

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    final results = <RenderedPage>[];
    try {
      var currentIdx = 0;
      final safeDpi = PdfRasterPolicy.safeDpi(pdfBytes, dpi);
      await for (final page in Printing.raster(
        pdfBytes,
        pages: pageIndices,
        dpi: safeDpi,
      )) {
        final pngBytes = await page.toPng();
        final actualPageNumber =
            pageIndices != null && currentIdx < pageIndices.length
            ? pageIndices[currentIdx] + 1
            : currentIdx + 1;

        results.add(
          RenderedPage(
            pageNumber: actualPageNumber,
            imageBytes: pngBytes,
            width: page.width,
            height: page.height,
          ),
        );
        currentIdx++;

        // Yield to event loop periodically for responsive UI on large multi-page scans
        if (currentIdx % 3 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (e) {
      debugPrint('PdfPageRenderer error: $e');
    }
    return results;
  }

  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    final list = await renderPages(
      pdfBytes,
      pageIndices: [pageIndex],
      dpi: dpi,
    );
    return list.isNotEmpty ? list.first : null;
  }
}
