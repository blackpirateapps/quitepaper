import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/pdf/pdf_document_builder.dart';
import '../../../../core/pdf/pdf_font_manager.dart';
import '../../../../core/pdf/pdf_markdown_parser.dart';
import '../../domain/export_models.dart';

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
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

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
}
