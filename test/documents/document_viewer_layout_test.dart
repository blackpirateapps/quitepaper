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
  for (final width in [320.0, 360.0, 390.0, 600.0]) {
    testWidgets(
      'toolbar retains title and options at ${width}px, clean and dirty',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await openSaveViewer(tester, SaveService());
        final controller = tester
            .widget<SfPdfViewer>(find.byType(SfPdfViewer))
            .controller!;
        for (final dirty in [false, true]) {
          if (dirty) {
            controller.addAnnotation(
              StickyNoteAnnotation(
                pageNumber: 1,
                icon: PdfStickyNoteIcon.comment,
                text: 'Note',
                position: const Offset(20, 20),
              ),
            );
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          final title = find.text('Save Test');
          expect(tester.getSize(title).width, greaterThanOrEqualTo(60));
          expect(find.textContaining('Page 1 of'), findsOneWidget);
          expect(find.byTooltip('Annotation Tools'), findsOneWidget);
          await tester.tap(find.byTooltip('Document options'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          for (final value in [
            'rename',
            'save',
            'share',
            'print',
            'regenerate_ocr',
          ]) {
            expect(
              find.byWidgetPredicate(
                (w) => w is PopupMenuItem<String> && w.value == value,
              ),
              findsOneWidget,
            );
          }
          await tester.tapAt(const Offset(5, 500));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  }
}
