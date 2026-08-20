import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/scanner/domain/scanned_page.dart';

/// Abstract contract for compiling page images into standards-compliant PDF documents.
abstract class PdfGenerator {
  Future<Uint8List> generatePdf(List<ScannedPage> pages);
}

/// Standard PDF generator using `pdf` package.
class DefaultPdfGenerator implements PdfGenerator {
  const DefaultPdfGenerator();

  @override
  Future<Uint8List> generatePdf(List<ScannedPage> pages) async {
    if (pages.isEmpty) {
      throw ArgumentError('Cannot generate PDF from empty page list');
    }

    final doc = pw.Document(
      title: 'Scanned Document',
      author: 'Quiet Paper',
      creator: 'Quiet Paper Document Subsystem',
    );

    for (final page in pages) {
      final imageBytes = page.finalImageBytes;
      final image = pw.MemoryImage(imageBytes);

      PdfPageFormat pageFormat = PdfPageFormat.a4;
      if (page.width > 0 && page.height > 0) {
        final aspect = page.width / page.height;
        if (aspect > 1.0) {
          // Landscape standard
          pageFormat = PdfPageFormat(
            PdfPageFormat.a4.height,
            PdfPageFormat.a4.width,
            marginAll: 0,
          );
        } else {
          // Portrait standard page matching aspect ratio
          pageFormat = PdfPageFormat(
            PdfPageFormat.a4.width,
            PdfPageFormat.a4.width / aspect,
            marginAll: 0,
          );
        }
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
