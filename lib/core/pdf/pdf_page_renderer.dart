import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

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
      await for (final page in Printing.raster(
        pdfBytes,
        pages: pageIndices,
        dpi: dpi,
      )) {
        final pngBytes = await page.toPng();
        final actualPageNumber = pageIndices != null && currentIdx < pageIndices.length
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
    final list = await renderPages(pdfBytes, pageIndices: [pageIndex], dpi: dpi);
    return list.isNotEmpty ? list.first : null;
  }
}
