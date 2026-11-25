import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
  const SyncfusionPdfPageRenderer({this.platform, this.customTempDirectory});

  final PdfViewerPlatform? platform;
  final Directory? customTempDirectory;

  // Concurrent thumbnails for the same source share one native document and
  // one page-size lookup. The final user closes it and removes its temp file.
  static final _sessions =
      <
        ({PdfViewerPlatform platform, Uint8List bytes, Directory? directory}),
        _NativeRasterSession
      >{};

  PdfViewerPlatform get effectivePlatform =>
      platform ?? PdfViewerPlatform.instance;

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    if (pdfBytes.isEmpty) return const [];

    final native = effectivePlatform;
    final key = (
      platform: native,
      bytes: pdfBytes,
      directory: customTempDirectory,
    );
    final session = _sessions.putIfAbsent(
      key,
      () => _NativeRasterSession(native, pdfBytes, customTempDirectory),
    );
    session.users++;
    final results = <RenderedPage>[];
    try {
      await session.ready;
      final docId = session.docId;
      final totalPages = session.pageCount;
      if (totalPages <= 0) return const [];
      final rawHeights = session.heights;
      final rawWidths = session.widths;

      final targetIndices = (pageIndices != null)
          ? pageIndices.where((idx) => idx >= 0 && idx < totalPages).toList()
          : List.generate(totalPages, (i) => i);

      for (final idx in targetIndices) {
        final widthPt = (idx < rawWidths.length && rawWidths[idx] is num)
            ? (rawWidths[idx] as num).toDouble()
            : 595.0;
        final heightPt = (idx < rawHeights.length && rawHeights[idx] is num)
            ? (rawHeights[idx] as num).toDouble()
            : 842.0;

        // Native dimensions are already available, including compressed page
        // dictionaries. Avoid rescanning the entire PDF for every thumbnail.
        final safeDpi = math.min(
          dpi,
          72 *
              math.sqrt(
                PdfRasterPolicy.maxPixelsPerPage / (widthPt * heightPt),
              ),
        );
        final pixelWidth = ((widthPt * safeDpi) / 72.0).round().clamp(1, 10000);
        final pixelHeight = ((heightPt * safeDpi) / 72.0).round().clamp(
          1,
          10000,
        );

        // syncfusion_pdfviewer_platform uses 1-based page numbers
        final pageNumber = idx + 1;
        final rawRgba = await native.getPage(
          pageNumber,
          pixelWidth,
          pixelHeight,
          docId,
        );

        if (rawRgba == null || rawRgba.isEmpty) continue;

        // PNG compression is CPU-heavy in debug builds. Keep it off the UI
        // isolate so sidebar work cannot block document navigation and input.
        final pngBytes = await compute(_encodePagePng, (
          bytes: rawRgba,
          width: pixelWidth,
          height: pixelHeight,
        ));

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
      session.users--;
      if (session.users == 0) {
        _sessions.remove(key);
        await session.close();
      }
    }

    return results;
  }

  static Uint8List _encodePagePng(
    ({Uint8List bytes, int width, int height}) page,
  ) {
    final image = img.Image.fromBytes(
      width: page.width,
      height: page.height,
      bytes: page.bytes.buffer,
      bytesOffset: page.bytes.offsetInBytes,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    );
    return Uint8List.fromList(img.encodePng(image));
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

class _NativeRasterSession {
  _NativeRasterSession(this.platform, Uint8List bytes, Directory? directory) {
    ready = _open(bytes, directory);
  }

  final PdfViewerPlatform platform;
  final String docId = const Uuid().v4();
  late final Future<void> ready;
  Directory? _directory;
  int users = 0;
  int pageCount = 0;
  List<dynamic> heights = const [];
  List<dynamic> widths = const [];

  Future<void> _open(Uint8List bytes, Directory? directory) async {
    final tempDir = await (directory ?? Directory.systemTemp).createTemp(
      'qp_syncfusion_renderer_',
    );
    _directory = tempDir;
    final file = File(p.join(tempDir.path, '$docId.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    pageCount =
        int.tryParse(await platform.loadPdfFromFile(file.path, docId) ?? '') ??
        0;
    if (pageCount > 0) {
      heights = await platform.getPagesHeight(docId) ?? const [];
      widths = await platform.getPagesWidth(docId) ?? const [];
    }
  }

  Future<void> close() async {
    try {
      await platform.closeDocument(docId);
    } catch (e) {
      debugPrint(
        '[SyncfusionPdfPageRenderer] Error closing native document: $e',
      );
    }
    try {
      final directory = _directory;
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {}
  }
}
