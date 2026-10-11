import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/pdf/pdf_document_builder.dart';
import '../../../../core/pdf/pdf_font_manager.dart';
import '../../../../core/pdf/pdf_markdown_parser.dart';
import '../../domain/export_models.dart';
import 'image_exporter.dart';

/// Wrapper class for font resolution to support test injection if needed.
class PdfFontManagerWrapper {
  const PdfFontManagerWrapper();

  Future<PdfTypographyTheme> resolveTypographyTheme({
    String? requestedBodyFamily,
    String? requestedCodeFamily,
  }) {
    return PdfFontManager.resolveTypographyTheme(
      requestedBodyFamily: requestedBodyFamily,
      requestedCodeFamily: requestedCodeFamily,
    );
  }
}

/// Exporter for compiling notes into searchable, vector text PDF documents (.pdf)
/// with full Markdown hierarchy, Unicode punctuation correctness, and embedded TrueType fonts.
class PdfExporter {
  const PdfExporter({
    this.fontManager = const PdfFontManagerWrapper(),
    this.markdownParser = const PdfMarkdownParser(),
    this.documentBuilder = const PdfDocumentBuilder(),
  });

  final PdfFontManagerWrapper fontManager;
  final PdfMarkdownParser markdownParser;
  final PdfDocumentBuilder documentBuilder;

  Future<ExportResult> exportPdf({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
    ImageRasterizer? imageRasterizer,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    // The `pdf` package lays glyphs out codepoint-by-codepoint with no complex-
    // script shaping (no GSUB/matra reordering), so Bengali conjuncts/vowel
    // signs mis-render in vector text. When the note contains Bengali and a
    // rasterizer is available, render the note through Flutter's shaping engine
    // (identical to image export, honoring the chosen Bengali font) and embed
    // the result as paginated images instead.
    if (imageRasterizer != null &&
        (_containsBengali(snapshot.markdown) ||
            _containsBengali(snapshot.effectiveTitle))) {
      try {
        return await _exportRasterizedPdf(
          snapshot: snapshot,
          request: request,
          outputFile: outputFile,
          rasterizer: imageRasterizer,
          stopwatch: stopwatch,
          warnings: warnings,
        );
      } catch (_) {
        // Fall through to the vector path if rasterization fails for any reason.
      }
    }

    // 1. Resolve embedded TrueType typography with full Unicode coverage
    final typography = await fontManager.resolveTypographyTheme();

    // 2. Build PDF Document with safe metadata
    final pdfDoc = pw.Document(
      title: snapshot.effectiveTitle,
      author: 'Quiet Paper',
      creator: 'Quiet Paper Export Subsystem',
    );

    final pdfOptions = request.pdfOptions;

    // 3. Build attachment byte map for embedded images
    final imageMap = <String, Uint8List>{};
    for (final att in snapshot.attachments) {
      if (att.hasBytes) {
        imageMap[att.relativePath] = att.bytes!;
        imageMap[att.id] = att.bytes!;
        imageMap['qp://asset/${att.id}'] = att.bytes!;
      }
    }

    // 4. Parse Markdown into semantic PDF blocks
    final blocks = markdownParser.parse(
      markdown: snapshot.markdown,
      imageMap: imageMap,
      includeAttachments: pdfOptions.includeAttachments,
    );

    // 5. Build Flow-based PDF Widgets
    final contentWidgets = documentBuilder.buildWidgets(
      snapshot: snapshot,
      request: request,
      blocks: blocks,
      typography: typography,
      warnings: warnings,
    );

    // 6. Map Page Size Format
    final pageFormat = _resolvePageFormat(pdfOptions.pageSize);

    // 7. Add Multi-page layout
    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        theme: typography.themeData,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Text(
                snapshot.effectiveTitle,
                style: pw.TextStyle(
                  font: typography.regular,
                  fontSize: 8.5,
                  color: PdfColors.grey500,
                ),
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                font: typography.regular,
                fontSize: 8.5,
                color: PdfColors.grey500,
              ),
            ),
          );
        },
        build: (pw.Context context) => contentWidgets,
      ),
    );

    // 8. Generate vector PDF bytes and save
    final bytes = await pdfDoc.save();
    await outputFile.writeAsBytes(bytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.pdf,
      filename: filename,
      byteSize: bytes.length,
      mimeType: ExportFormat.pdf.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static PdfPageFormat _resolvePageFormat(String pageSize) {
    switch (pageSize.toUpperCase()) {
      case 'LETTER':
        return PdfPageFormat.letter;
      case 'LEGAL':
        return PdfPageFormat.legal;
      case 'A3':
        return PdfPageFormat.a3;
      case 'A5':
        return PdfPageFormat.a5;
      case 'A4':
      default:
        return PdfPageFormat.a4;
    }
  }

  static final RegExp _bengaliRegExp = RegExp(r'[ঀ-৿]');

  static bool _containsBengali(String text) => _bengaliRegExp.hasMatch(text);

  /// Renders the note to a single tall PNG via Flutter's shaping engine, slices
  /// it into page-height tiles, and assembles an image-based PDF. Used for notes
  /// containing Bengali, which the vector text engine cannot shape correctly.
  Future<ExportResult> _exportRasterizedPdf({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
    required ImageRasterizer rasterizer,
    required Stopwatch stopwatch,
    required List<ExportWarning> warnings,
  }) async {
    // Render on a wider, light, brand-free canvas suited to a document page.
    final rasterRequest = request.copyWith(
      imageOptions: request.imageOptions.copyWith(
        themeMode: 'light',
        includeBranding: false,
        logicalWidth: request.imageOptions.logicalWidth < 800
            ? 800.0
            : request.imageOptions.logicalWidth,
      ),
    );

    final pngBytes = await rasterizer(
      snapshot: snapshot,
      request: rasterRequest,
    );

    final decoded = img.decodeImage(pngBytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw StateError('Failed to decode rasterized note image for PDF.');
    }

    final pageFormat = _resolvePageFormat(request.pdfOptions.pageSize);
    const double margin = 28.0;
    final double contentWpts = pageFormat.width - margin * 2;
    final double contentHpts = pageFormat.height - margin * 2;

    final int imgW = decoded.width;
    final int imgH = decoded.height;
    final double ptsPerPx = contentWpts / imgW;
    // Height of one page's worth of pixels from the source image.
    int sliceHpx = (contentHpts / ptsPerPx).floor();
    if (sliceHpx < 1) sliceHpx = imgH;

    final doc = pw.Document(
      title: snapshot.effectiveTitle,
      author: 'Quiet Paper',
      creator: 'Quiet Paper Export Subsystem',
    );

    for (int y = 0; y < imgH; y += sliceHpx) {
      final int cropH = (y + sliceHpx <= imgH) ? sliceHpx : (imgH - y);
      final img.Image tile =
          img.copyCrop(decoded, x: 0, y: y, width: imgW, height: cropH);
      final Uint8List tilePng = Uint8List.fromList(img.encodePng(tile));
      final memImage = pw.MemoryImage(tilePng);
      final double tileHpts = cropH * ptsPerPx;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pw.Align(
              alignment: pw.Alignment.topCenter,
              child: pw.Image(
                memImage,
                width: contentWpts,
                height: tileHpts,
                fit: pw.BoxFit.fitWidth,
              ),
            );
          },
        ),
      );
    }

    warnings.add(const ExportWarning(
      type: ExportWarningType.partialContent,
      message:
          'Bengali note was exported as rendered page images to preserve correct '
          'script shaping; the PDF text is not selectable.',
    ));

    final bytes = await doc.save();
    await outputFile.writeAsBytes(bytes, flush: true);
    stopwatch.stop();

    return ExportResult(
      file: outputFile,
      format: ExportFormat.pdf,
      filename: outputFile.uri.pathSegments.last,
      byteSize: bytes.length,
      mimeType: ExportFormat.pdf.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }
}
