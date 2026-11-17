import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import '../pdf/syncfusion_pdf_page_renderer_test.dart'
    show FakePdfViewerPlatform;
import 'document_viewer_save_test.dart' show SaveService, openSaveViewer;

void main() {
  setUp(() {
    final previous = PdfViewerPlatform.instance;
    PdfViewerPlatform.instance = FakePdfViewerPlatform()
      ..pageCountToReturn = 1
      ..heightsToReturn = [842]
      ..widthsToReturn = [595];
    addTearDown(() => PdfViewerPlatform.instance = previous);
  });

  testWidgets(
    'PDF load failure shows error and Try Again reloads the document',
    (tester) async {
      final service = SaveService();
      await openSaveViewer(tester, service);
      final viewer = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer));
      viewer.onDocumentLoadFailed!(
        PdfDocumentLoadFailedDetails(
          'Format Error',
          'This document cannot be opened because it is corrupted or not a PDF.',
        ),
      );
      await tester.pump();
      expect(find.text('Document Unavailable'), findsOneWidget);
      expect(find.textContaining('corrupted or not a PDF'), findsOneWidget);
      expect(find.byType(SfPdfViewer), findsNothing);
      expect(find.byTooltip('Zoom in'), findsNothing);
      expect(find.textContaining('Page 1 of'), findsNothing);
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(service.resolveCalls, 1);
      expect(find.text('Document Unavailable'), findsNothing);
      expect(find.byType(SfPdfViewer), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    },
  );
}
