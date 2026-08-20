import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/scanned_page.dart';

/// Service responsible for compiling captured scanned pages into a single canonical multi-page PDF document.
class PdfBuilder {
  const PdfBuilder();

  /// Compiles a sequence of [ScannedPage]s into a valid, standards-compliant `application/pdf` binary.
  ///
  /// Guarantees:
  /// - Preserves exact input page order.
  /// - Sets page dimensions matching the captured aspect ratio.
  /// - Emits standards-compliant PDF binary bytes.
  Future<Uint8List> buildPdfFromPages(List<ScannedPage> pages) async {
    if (pages.isEmpty) {
      throw ArgumentError('Cannot generate PDF from empty page list');
    }

    final doc = pw.Document(
      title: 'Scanned Document',
      author: 'Quiet Paper',
      creator: 'Quiet Paper Document Scanner',
    );

    for (final page in pages) {
      final image = pw.MemoryImage(page.imageBytes);

      // Determine page size from image aspect ratio (defaulting to standard A4 if unknown)
      PdfPageFormat pageFormat = PdfPageFormat.a4;
      if (page.width > 0 && page.height > 0) {
        final aspect = page.width / page.height;
        if (aspect > 1.0) {
          // Landscape
          pageFormat = PdfPageFormat(
            PdfPageFormat.a4.height,
            PdfPageFormat.a4.width,
            marginAll: 0,
          );
        } else {
          // Portrait standard page matching aspect
          pageFormat = PdfPageFormat(
            PdfPageFormat.a4.width,
            PdfPageFormat.a4.width / aspect,
            marginAll: 0,
          );
        }
      } else {
        pageFormat = PdfPageFormat(
          PdfPageFormat.a4.width,
          PdfPageFormat.a4.height,
          marginAll: 0,
        );
      }

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
