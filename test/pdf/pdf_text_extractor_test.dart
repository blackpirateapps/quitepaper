import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/pdf/pdf_text_extractor.dart';

void main() {
  group('DefaultPdfTextExtractor Embedded Text Layer Tests', () {
    late DefaultPdfTextExtractor extractor;

    setUp(() {
      extractor = const DefaultPdfTextExtractor();
    });

    test(
      'Returns hasUsableText: false for raw raster binary with no text layer',
      () async {
        final rasterFakePdf = Uint8List.fromList(
          List.generate(500, (i) => i % 256),
        );
        final result = await extractor.extractText(rasterFakePdf);

        expect(result.hasUsableText, isFalse);
        expect(result.pages, isEmpty);
        expect(result.extractedText, isEmpty);
      },
    );

    test('Returns hasUsableText: false for empty or tiny buffer', () async {
      final result = await extractor.extractText(Uint8List(5));
      expect(result.hasUsableText, isFalse);
      expect(result.pages, isEmpty);
    });

    test(
      'Bounds extraction before an unsupported PDF can block processing',
      () async {
        const timedExtractor = DefaultPdfTextExtractor(
          extractionTimeout: Duration.zero,
        );
        final result = await timedExtractor.extractText(
          Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj\n<<>>\nendobj')),
        );

        expect(result.hasUsableText, isFalse);
        expect(result.timedOut, isTrue);
      },
    );

    test(
      'Extracts tagged PDF text with marked-content property dictionaries',
      () async {
        const taggedPdf = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 110 >>
stream
BT
/F1 12 Tf
72 700 Td
/Span << /MCID 0 >> BDC
(Tagged PDF text remains extractable) Tj
EMC
ET
endstream
endobj
%%EOF
''';

        final result = await extractor.extractText(
          Uint8List.fromList(utf8.encode(taggedPdf)),
        );

        expect(result.timedOut, isFalse);
        expect(result.hasUsableText, isTrue);
        expect(
          result.extractedText,
          contains('Tagged PDF text remains extractable'),
        );
      },
    );

    test('Extracts text from uncompressed PDF stream', () async {
      const mockPdfStream = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 120 >>
stream
BT
/F1 12 Tf
72 700 Td
(Quiet Paper Encrypted Notes) Tj
0 -20 Td
(Second line of confidential document) Tj
ET
endstream
endobj
%%EOF
''';

      final pdfBytes = Uint8List.fromList(utf8.encode(mockPdfStream));
      final result = await extractor.extractText(pdfBytes);

      expect(result.hasUsableText, isTrue);
      expect(result.pages.length, equals(1));
      expect(result.extractedText, contains('Quiet Paper Encrypted Notes'));
      expect(
        result.extractedText,
        contains('Second line of confidential document'),
      );
      expect(result.pages.first.source, equals(OcrSource.embeddedPdfText));
      expect(result.pages.first.blocks.isNotEmpty, isTrue);
    });

    test('Extracts text from FlateDecode compressed stream', () async {
      const rawContent = '''
BT
/F1 14 Tf
50 720 Td
(Zero-Knowledge Architecture Overview) Tj
0 -30 Td
(Argon2id and XChaCha20-Poly1305 Security) Tj
ET
''';
      final compressedContent = Uint8List.fromList(
        zlib.encode(utf8.encode(rawContent)),
      );

      final pdfHeader = utf8.encode('''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length ${compressedContent.length} /Filter /FlateDecode >>
stream
''');
      final pdfFooter = utf8.encode('''
\nendstream
endobj
%%EOF
''');

      final fullPdf = Uint8List.fromList([
        ...pdfHeader,
        ...compressedContent,
        ...pdfFooter,
      ]);
      final result = await extractor.extractText(fullPdf);

      expect(result.hasUsableText, isTrue);
      expect(result.pages.length, equals(1));
      expect(
        result.extractedText,
        contains('Zero-Knowledge Architecture Overview'),
      );
      expect(
        result.extractedText,
        contains('Argon2id and XChaCha20-Poly1305 Security'),
      );
    });

    test(
      'Extracts text from multi-page document with accurate per-page isolation',
      () async {
        const page1Content =
            'BT /F1 12 Tf 50 700 Td (Page One Header Content) Tj ET';
        const page2Content =
            'BT /F1 12 Tf 50 700 Td (Page Two Footer Content) Tj ET';

        final mockPdf =
            '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>
endobj
4 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>
endobj
5 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
6 0 obj
<< /Length ${page1Content.length} >>
stream
$page1Content
endstream
endobj
7 0 obj
<< /Length ${page2Content.length} >>
stream
$page2Content
endstream
endobj
%%EOF
''';

        final pdfBytes = Uint8List.fromList(utf8.encode(mockPdf));
        final result = await extractor.extractText(pdfBytes);

        expect(result.hasUsableText, isTrue);
        expect(result.pages.length, equals(2));
        expect(result.pages[0].plainText, contains('Page One Header Content'));
        expect(result.pages[0].plainText, isNot(contains('Page Two')));
        expect(result.pages[1].plainText, contains('Page Two Footer Content'));
        expect(result.pages[1].plainText, isNot(contains('Page One')));
      },
    );

    test('Extracts text with /ToUnicode CMap font mapping', () async {
      const toUnicodeCMap = '''
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /Custom-ToUnicode def
/CMapType 2 def
1 begincodespacerange
<00> <FF>
endcodespacerange
2 beginbfchar
<01> <0048>
<02> <0069>
endbfchar
1 beginbfrange
<03> <04> <0041>
endbfrange
endcmap
CMapName currentdict /CMap defineresource pop
end
end
''';

      final cmapBytes = Uint8List.fromList(utf8.encode(toUnicodeCMap));

      final mockPdf =
          '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 500 700] /Resources << /Font << /F1 4 0 R >> >> /Contents 6 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /TrueType /BaseFont /CustomFont /ToUnicode 5 0 R >>
endobj
5 0 obj
<< /Length ${cmapBytes.length} >>
stream
$toUnicodeCMap
endstream
endobj
6 0 obj
<< /Length 40 >>
stream
BT
/F1 12 Tf
50 600 Td
<01020304> Tj
ET
endstream
endobj
%%EOF
''';

      final pdfBytes = Uint8List.fromList(utf8.encode(mockPdf));
      final result = await extractor.extractText(pdfBytes);

      expect(result.hasUsableText, isTrue);
      expect(result.pages.length, equals(1));
      // <01> -> 'H', <02> -> 'i', <03> -> 'A', <04> -> 'B' => "HiAB"
      expect(result.extractedText, contains('HiAB'));
    });

    test(
      'Extracts text with TJ kerning array and synthesizes word boundaries',
      () async {
        const mockPdf = '''
%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>
endobj
4 0 obj
<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
endobj
5 0 obj
<< /Length 100 >>
stream
BT
/F1 12 Tf
50 700 Td
[ (Quiet) -250 (Paper) -200 (Sync) ] TJ
ET
endstream
endobj
%%EOF
''';

        final pdfBytes = Uint8List.fromList(utf8.encode(mockPdf));
        final result = await extractor.extractText(pdfBytes);

        expect(result.hasUsableText, isTrue);
        expect(result.extractedText, contains('Quiet Paper Sync'));
      },
    );

    test(
      'Extracts text from real-world binary PDF generated via pdf package',
      () async {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    text: 'Quiet Paper Product Specification',
                  ),
                  pw.Paragraph(
                    text:
                        'Quiet Paper is an offline-first notes application inspired by Bear Notes with zero-knowledge end-to-end encryption.',
                  ),
                  pw.Paragraph(
                    text:
                        'Local persistence is managed by Drift SQLite, ensuring high performance without latency.',
                  ),
                ],
              );
            },
          ),
        );

        final realPdfBytes = await doc.save();
        expect(realPdfBytes.isNotEmpty, isTrue);

        final result = await extractor.extractText(realPdfBytes);

        expect(result.hasUsableText, isTrue);
        expect(result.pages.length, equals(1));
        expect(
          result.extractedText,
          contains('Quiet Paper Product Specification'),
        );
        expect(
          result.extractedText,
          contains('offline-first notes application'),
        );
        expect(
          result.extractedText,
          contains('zero-knowledge end-to-end encryption'),
        );
        expect(result.pages.first.source, equals(OcrSource.embeddedPdfText));
        expect(result.pages.first.blocks.length, greaterThanOrEqualTo(1));
      },
    );

    test('Extracts text from real-world multi-page binary PDF', () async {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Header(
              level: 0,
              text: 'Chapter 1: Encryption Architecture',
            );
          },
        ),
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Header(level: 0, text: 'Chapter 2: Master Key Hierarchy');
          },
        ),
      );

      final realPdfBytes = await doc.save();
      final result = await extractor.extractText(realPdfBytes);

      expect(result.hasUsableText, isTrue);
      expect(result.pages.length, equals(2));
      expect(
        result.pages[0].plainText,
        contains('Chapter 1: Encryption Architecture'),
      );
      expect(result.pages[0].plainText, isNot(contains('Chapter 2')));
      expect(
        result.pages[1].plainText,
        contains('Chapter 2: Master Key Hierarchy'),
      );
      expect(result.pages[1].plainText, isNot(contains('Chapter 1')));
    });
  });
}
