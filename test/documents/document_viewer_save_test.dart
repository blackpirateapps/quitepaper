import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
// Syncfusion exposes these document types through its viewer callbacks.
// ignore: depend_on_referenced_packages
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import '../pdf/syncfusion_pdf_page_renderer_test.dart'
    show FakePdfViewerPlatform;

class SaveService extends Fake implements DocumentService {
  Completer<void>? gate;
  bool fail = false;
  late ResourceResolution<ResolvedDocumentInfo> resolution;
  int resolveCalls = 0;
  @override
  Future<ResourceResolution<ResolvedDocumentInfo>> resolveDocument(
    String documentId,
  ) async {
    resolveCalls++;
    return resolution;
  }

  final saved = <Uint8List>[];
  @override
  Future<Uint8List?> resolveAnnotatedBytes(String documentId) async => null;
  @override
  Future<void> saveAnnotatedDocument({
    required String documentId,
    required Uint8List annotatedPdfBytes,
  }) async {
    saved.add(annotatedPdfBytes);
    await gate?.future;
    if (fail) throw StateError('Storage unavailable');
  }
}

class SaveThumbnails extends Fake implements PdfThumbnailService {
  @override
  Future<void> deleteThumbnails(String documentId) async {}
}

Future<void> openSaveViewer(WidgetTester tester, SaveService service) async {
  SharedPreferences.setMockInitialValues({
    'setting_pdf_thumbnail_sidebar_open': false,
  });
  final pdf = pw.Document()
    ..addPage(pw.Page(build: (_) => pw.Text('Save test')));
  final bytes = await pdf.save();
  final resolution = ResourceResolution.available(
    QuietPaperUri.document('save-test'),
    ResolvedDocumentInfo(
      documentId: 'save-test',
      title: 'Save Test',
      pdfBytes: bytes,
      pageCount: 1,
      byteSize: bytes.length,
      sha256: 'test',
    ),
  );
  service.resolution = resolution;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentServiceProvider.overrideWithValue(service),
        pdfThumbnailServiceProvider.overrideWithValue(SaveThumbnails()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => DocumentViewerScreen.open(
                context,
                documentId: 'save-test',
                initialResolution: resolution,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() {
    final previous = PdfViewerPlatform.instance;
    PdfViewerPlatform.instance = FakePdfViewerPlatform()
      ..pageCountToReturn = 1
      ..heightsToReturn = [842]
      ..widthsToReturn = [595];
    addTearDown(() => PdfViewerPlatform.instance = previous);
  });
  testWidgets('pending save preserves newer annotations and live source', (
    tester,
  ) async {
    final service = SaveService()..gate = Completer<void>();
    await openSaveViewer(tester, service);
    final viewer = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer));
    // Use the real controller and serializer; native raster output is irrelevant.
    viewer.controller!.addAnnotation(
      StickyNoteAnnotation(
        pageNumber: 1,
        icon: PdfStickyNoteIcon.comment,
        text: 'A',
        position: const Offset(20, 20),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save Annotations'));
    await tester.pump();
    expect(service.saved, hasLength(1));
    viewer.controller!.addAnnotation(
      StickyNoteAnnotation(
        pageNumber: 1,
        icon: PdfStickyNoteIcon.comment,
        text: 'B',
        position: const Offset(40, 40),
      ),
    );
    await tester.pump();
    service.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(viewer.controller!.getAnnotations(), hasLength(2));
    expect(
      tester.widget<SfPdfViewer>(find.byType(SfPdfViewer)).key,
      viewer.key,
    );
    expect(find.byTooltip('Save Annotations'), findsOneWidget);
    service.gate = null;
    await tester.tap(find.byTooltip('Save Annotations'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(service.saved, hasLength(2));
    final reopened = sf.PdfDocument(inputBytes: service.saved.last);
    expect(reopened.pages[0].annotations.count, 2);
    reopened.dispose();
    expect(find.byTooltip('Save Annotations'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
  testWidgets(
    'failed Back save keeps annotations open and Retry saves before exit',
    (tester) async {
      final service = SaveService()..fail = true;
      await openSaveViewer(tester, service);
      final viewer = tester.widget<SfPdfViewer>(find.byType(SfPdfViewer));
      viewer.controller!.addAnnotation(
        StickyNoteAnnotation(
          pageNumber: 1,
          icon: PdfStickyNoteIcon.comment,
          text: 'Keep me',
          position: const Offset(20, 20),
        ),
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DocumentViewerScreen), findsOneWidget);
      expect(viewer.controller!.getAnnotations(), hasLength(1));
      expect(find.text('Retry'), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DocumentViewerScreen), findsNothing);
      final reopened = sf.PdfDocument(inputBytes: service.saved.last);
      expect(reopened.pages[0].annotations.count, 1);
      reopened.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets('Back waits for pending save and saves newer edits before exit', (
    tester,
  ) async {
    final service = SaveService()..gate = Completer<void>();
    await openSaveViewer(tester, service);
    final controller = tester
        .widget<SfPdfViewer>(find.byType(SfPdfViewer))
        .controller!;
    controller.addAnnotation(
      StickyNoteAnnotation(
        pageNumber: 1,
        icon: PdfStickyNoteIcon.comment,
        text: 'A',
        position: const Offset(20, 20),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save Annotations'));
    await tester.pump();
    controller.addAnnotation(
      StickyNoteAnnotation(
        pageNumber: 1,
        icon: PdfStickyNoteIcon.comment,
        text: 'B',
        position: const Offset(40, 40),
      ),
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(find.byType(DocumentViewerScreen), findsOneWidget);
    expect(service.saved, hasLength(1));
    service.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DocumentViewerScreen), findsNothing);
    expect(service.saved, hasLength(2));
    final reopened = sf.PdfDocument(inputBytes: service.saved.last);
    expect(reopened.pages[0].annotations.count, 2);
    reopened.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
