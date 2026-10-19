import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw_widgets;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';

Future<Uint8List> _generateTestPdf() async {
  final pdf = pw_widgets.Document();
  pdf.addPage(
    pw_widgets.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw_widgets.Context context) {
        return pw_widgets.Center(
          child: pw_widgets.Text(
            'Selection phase admit certificate candidate roll number 42615302658',
            style: const pw_widgets.TextStyle(fontSize: 16),
          ),
        );
      },
    ),
  );
  return pdf.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentViewerScreen Custom Text Selection & Search Tests', () {
    late Uint8List samplePdfBytes;
    const testDocId = 'doc-selection-test';

    setUp(() async {
      samplePdfBytes = await _generateTestPdf();
    });

    testWidgets('Renders DocumentViewerScreen and has search option in overflow menu', (tester) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          title: 'Admit Card',
          pdfBytes: samplePdfBytes,
          pageCount: 1,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          ocrState: 'ready',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Admit Card',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Admit Card'), findsWidgets);

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Search in Document'), findsOneWidget);
    });
  });
}
