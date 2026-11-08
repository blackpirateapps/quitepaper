import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import 'package:uuid/uuid.dart';

import 'pdf_page_renderer.dart';

/// PDF page renderer utilizing Syncfusion's native platform interface
/// (`syncfusion_pdfviewer_platform_interface`).
///
/// Specifically calibrated for Linux and desktop platforms where standard
/// `Printing.raster` tears down the process-wide PDFium singleton via
/// `FPDF_DestroyLibrary()` upon job completion, deadlocking or crashing
/// concurrent [SfPdfViewer] instances.
///
/// Syncfusion's native renderer tracks active document handles in an internal
/// repository (`documentRepo`) and only destroys the PDFium library if zero
/// documents remain open across the entire application.
class SyncfusionPdfPageRenderer implements PdfPageRenderer {
  const SyncfusionPdfPageRenderer({
    this.platform,
    this.customTempDirectory,
  });

  final PdfViewerPlatform? platform;
  final Directory? customTempDirectory;

  PdfViewerPlatform get effectivePlatform =>
      platform ?? PdfViewerPlatform.instance;

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    if (pdfBytes.isEmpty) return const [];

    final docId = const Uuid().v4();
    final parentDir = customTempDirectory ?? Directory.systemTemp;
    final tempDir = await parentDir.createTemp('qp_syncfusion_renderer_');
    final tempFile = File(p.join(tempDir.path, '$docId.pdf'));
    await tempFile.writeAsBytes(pdfBytes, flush: true);

    final results = <RenderedPage>[];

    try {
      final pageCountStr =
          await effectivePlatform.loadPdfFromFile(tempFile.path, docId);
      final totalPages = int.tryParse(pageCountStr ?? '') ?? 0;
      if (totalPages <= 0) return const [];

      final rawHeights =
          await effectivePlatform.getPagesHeight(docId) ?? const [];
      final rawWidths =
          await effectivePlatform.getPagesWidth(docId) ?? const [];

      final targetIndices = (pageIndices != null)
          ? pageIndices.where((idx) => idx >= 0 && idx < totalPages).toList()
          : List.generate(totalPages, (i) => i);

      final safeDpi = PdfRasterPolicy.safeDpi(pdfBytes, dpi);

      for (final idx in targetIndices) {
        final widthPt = (idx < rawWidths.length && rawWidths[idx] is num)
            ? (rawWidths[idx] as num).toDouble()
            : 595.0;
        final heightPt = (idx < rawHeights.length && rawHeights[idx] is num)
            ? (rawHeights[idx] as num).toDouble()
            : 842.0;

        final pixelWidth =
            ((widthPt * safeDpi) / 72.0).round().clamp(1, 10000);
        final pixelHeight =
            ((heightPt * safeDpi) / 72.0).round().clamp(1, 10000);

        // syncfusion_pdfviewer_platform uses 1-based page numbers
        final pageNumber = idx + 1;
        final rawRgba = await effectivePlatform.getPage(
          pageNumber,
          pixelWidth,
          pixelHeight,
          docId,
        );

        if (rawRgba == null || rawRgba.isEmpty) continue;

        final image = img.Image.fromBytes(
          width: pixelWidth,
          height: pixelHeight,
          bytes: rawRgba.buffer,
          order: img.ChannelOrder.rgba,
          numChannels: 4,
        );

        final pngBytes = Uint8List.fromList(img.encodePng(image));

        results.add(
          RenderedPage(
            pageNumber: pageNumber,
            imageBytes: pngBytes,
            width: pixelWidth,
            height: pixelHeight,
          ),
        );

        // Yield to event loop periodically for responsive UI on large multi-page scans
        if (results.length % 3 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } catch (e) {
      debugPrint('[SyncfusionPdfPageRenderer] Error rendering pages: $e');
    } finally {
      try {
        await effectivePlatform.closeDocument(docId);
      } catch (e) {
        debugPrint(
          '[SyncfusionPdfPageRenderer] Error closing native document: $e',
        );
      }
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
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
