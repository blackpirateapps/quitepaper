import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw_widgets;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FakeZoomDocumentService extends Fake implements DocumentService {
  @override
  Future<Uint8List?> resolveAnnotatedBytes(String documentId) async => null;
}

Future<Uint8List> _generateMultiPageTestPdf() async {
  final pdf = pw_widgets.Document();
  pdf.addPage(
    pw_widgets.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw_widgets.Context context) {
        return pw_widgets.Center(
          child: pw_widgets.Text('Page 1 Content: Scanned Contract Details'),
        );
      },
    ),
  );
  pdf.addPage(
    pw_widgets.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw_widgets.Context context) {
        return pw_widgets.Center(
          child: pw_widgets.Text('Page 2 Content: Signatures and Footnotes'),
        );
      },
    ),
  );
  return pdf.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentViewerScreen Zoom & Performance Tests', () {
    late Uint8List samplePdfBytes;
    const testDocId = 'doc-zoom-test';
    late FakeZoomDocumentService fakeService;

    setUp(() async {
      samplePdfBytes = await _generateMultiPageTestPdf();
      fakeService = FakeZoomDocumentService();
    });

    testWidgets(
      'SfPdfViewer is configured with maxZoomLevel 12.0 and mobile scrollhead is false on mobile',
      (tester) async {
        final resolution = ResourceResolution.available(
          QuietPaperUri.document(testDocId),
          ResolvedDocumentInfo(
            documentId: testDocId,
            title: 'Contract Scan',
            pdfBytes: samplePdfBytes,
            pageCount: 2,
            byteSize: samplePdfBytes.length,
            sha256: 'mocksha',
            ocrState: 'ready',
          ),
        );

        // Wrap in Android platform theme to simulate mobile device
        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.android,
              ),
              home: DocumentViewerScreen(
                documentId: testDocId,
                title: 'Contract Scan',
                initialResolution: resolution,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final pdfViewerFinder = find.byType(SfPdfViewer);
        expect(pdfViewerFinder, findsOneWidget);

        final SfPdfViewer pdfViewer = tester.widget<SfPdfViewer>(
          pdfViewerFinder,
        );
        expect(pdfViewer.maxZoomLevel, equals(12.0));
        expect(pdfViewer.maxZoomLevel, equals(kPdfViewerMaxZoomLevel));
        // On mobile (Android/iOS), scrollhead must be disabled to prevent pinch-zoom gesture conflicts
        expect(pdfViewer.canShowScrollHead, isFalse);
        expect(pdfViewer.canShowScrollStatus, isFalse);

        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets(
      'SfPdfViewer enables desktop scrollbars when platform is Linux or Windows',
      (tester) async {
        final resolution = ResourceResolution.available(
          QuietPaperUri.document(testDocId),
          ResolvedDocumentInfo(
            documentId: testDocId,
            title: 'Contract Scan',
            pdfBytes: samplePdfBytes,
            pageCount: 2,
            byteSize: samplePdfBytes.length,
            sha256: 'mocksha',
            ocrState: 'ready',
          ),
        );

        // Desktop platform
        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(platform: TargetPlatform.linux),
              home: DocumentViewerScreen(
                documentId: testDocId,
                title: 'Contract Scan',
                initialResolution: resolution,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final SfPdfViewer pdfViewer = tester.widget<SfPdfViewer>(
          find.byType(SfPdfViewer),
        );
        expect(pdfViewer.canShowScrollHead, isTrue);
        expect(pdfViewer.canShowScrollStatus, isTrue);

        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets(
      'Renders floating quick-zoom pill with 100% initial zoom and functional zoom step controls',
      (tester) async {
        final resolution = ResourceResolution.available(
          QuietPaperUri.document(testDocId),
          ResolvedDocumentInfo(
            documentId: testDocId,
            title: 'Contract Scan',
            pdfBytes: samplePdfBytes,
            pageCount: 2,
            byteSize: samplePdfBytes.length,
            sha256: 'mocksha',
            ocrState: 'ready',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.android,
              ),
              home: DocumentViewerScreen(
                documentId: testDocId,
                title: 'Contract Scan',
                initialResolution: resolution,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Floating zoom pill should display 100%
        expect(find.text('100%'), findsOneWidget);
        expect(find.byTooltip('Zoom in'), findsOneWidget);
        expect(find.byTooltip('Zoom out'), findsOneWidget);

        // Tap Zoom In button
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should be zoomed to ~135%
        expect(find.text('135%'), findsOneWidget);

        // Tap Zoom In again
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1.35 * 1.35 = ~1.82 -> 182%
        expect(find.text('182%'), findsOneWidget);

        // Tap Reset / Percentage button to return to 100% Fit
        await tester.tap(find.text('182%'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('100%'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets(
      'Updates page counter dynamically via ValueListenable without re-creating SfPdfViewer',
      (tester) async {
        final resolution = ResourceResolution.available(
          QuietPaperUri.document(testDocId),
          ResolvedDocumentInfo(
            documentId: testDocId,
            title: 'Contract Scan',
            pdfBytes: samplePdfBytes,
            pageCount: 2,
            byteSize: samplePdfBytes.length,
            sha256: 'mocksha',
            ocrState: 'ready',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [documentServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.android,
              ),
              home: DocumentViewerScreen(
                documentId: testDocId,
                title: 'Contract Scan',
                initialResolution: resolution,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.textContaining('Page 1 of 2'), findsOneWidget);

        // Simulate onPageChanged callback from SfPdfViewer
        final SfPdfViewer pdfViewer = tester.widget<SfPdfViewer>(
          find.byType(SfPdfViewer),
        );
        pdfViewer.onPageChanged?.call(PdfPageChangedDetails(2, 1, false, true));
        await tester.pump();

        // Page counter should update to Page 2 of 2
        expect(find.textContaining('Page 2 of 2'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets('Floating zoom pill is hidden when entering annotation mode', (
      tester,
    ) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          title: 'Contract Scan',
          pdfBytes: samplePdfBytes,
          pageCount: 2,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          ocrState: 'ready',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [documentServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Contract Scan',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('100%'), findsOneWidget);

      // Open annotation tools modal
      await tester.tap(find.byTooltip('Annotation Tools'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select Highlight mode
      await tester.tap(find.text('Highlight Text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // In annotation mode, zoom pill is hidden to free drawing canvas
      expect(find.text('100%'), findsNothing);
      expect(find.textContaining('Highlight Mode'), findsOneWidget);

      // Exit annotation mode
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Zoom pill returns
      expect(find.text('100%'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
