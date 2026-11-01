import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw_widgets;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/documents/presentation/widgets/pdf_thumbnail_sidebar.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() => masterKey;

  @override
  void lock() => isUnlocked = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdfPageRenderer implements PdfPageRenderer {
  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    return [
      for (final idx in (pageIndices ?? [0]))
        RenderedPage(
          pageNumber: idx + 1,
          imageBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, idx]),
          width: 80,
          height: 110,
        ),
    ];
  }

  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    final list = await renderPages(
      pdfBytes,
      pageIndices: [pageIndex],
      dpi: dpi,
    );
    return list.isNotEmpty ? list.first : null;
  }
}

class FakeViewerDocumentService extends Fake implements DocumentService {
  @override
  Future<Uint8List?> resolveAnnotatedBytes(String documentId) async => null;
}

Future<Uint8List> _generateTestPdf() async {
  final pdf = pw_widgets.Document();
  pdf.addPage(
    pw_widgets.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw_widgets.Context context) {
        return pw_widgets.Center(
          child: pw_widgets.Text('Page 1 Contract'),
        );
      },
    ),
  );
  pdf.addPage(
    pw_widgets.Page(
      pageFormat: pw.PdfPageFormat.a4,
      build: (pw_widgets.Context context) {
        return pw_widgets.Center(
          child: pw_widgets.Text('Page 2 Terms'),
        );
      },
    ),
  );
  return pdf.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentViewerScreen Thumbnail Sidebar Tests', () {
    late Uint8List samplePdfBytes;
    const testDocId = 'doc-thumb-screen-test';
    late FakeViewerDocumentService fakeDocService;
    late PdfThumbnailService testThumbnailService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      samplePdfBytes = await _generateTestPdf();
      fakeDocService = FakeViewerDocumentService();

      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      final keyManager = MockKeyManager(masterKey: masterKey);

      testThumbnailService = PdfThumbnailService(
        keyManager: keyManager,
        crypto: DocumentCrypto(cryptoService: cryptoService),
        renderer: FakePdfPageRenderer(),
      );
    });

    testWidgets('Large screen (>= 768dp) displays sidebar toggle and collapsible thumbnail sidebar',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          title: 'Document with Thumbnails',
          pdfBytes: samplePdfBytes,
          pageCount: 2,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          ocrState: 'ready',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(fakeDocService),
            pdfThumbnailServiceProvider.overrideWithValue(testThumbnailService),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.linux),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Document with Thumbnails',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sidebar toggle button should exist in AppBar
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.tooltip == 'Hide thumbnails' || w.tooltip == 'Show thumbnails'),
        ),
        findsOneWidget,
      );

      // Thumbnail sidebar collapse handle should exist on large screen
      final collapseHandle = find.bySemanticsLabel(RegExp(r'(Collapse|Expand) thumbnail sidebar'));
      expect(collapseHandle, findsOneWidget);

      // Verify toggle action
      await tester.tap(collapseHandle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Can be toggled again via the AppBar button
      final appbarToggle = find.byWidgetPredicate(
        (w) =>
            w is IconButton &&
            (w.tooltip == 'Hide thumbnails' || w.tooltip == 'Show thumbnails'),
      );
      await tester.tap(appbarToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Small mobile screen (< 768dp) hides thumbnail sidebar toggle',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          title: 'Mobile Document',
          pdfBytes: samplePdfBytes,
          pageCount: 2,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          ocrState: 'ready',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(fakeDocService),
            pdfThumbnailServiceProvider.overrideWithValue(testThumbnailService),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Mobile Document',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Toggle button must NOT exist on phone screen
      final toggleFinder = find.byTooltip('Hide thumbnails');
      final toggleAlternative = find.byTooltip('Show thumbnails');
      expect(toggleFinder, findsNothing);
      expect(toggleAlternative, findsNothing);
      expect(find.byType(PdfThumbnailSidebar), findsNothing);

      // Clean up widget tree to dismiss SfPdfViewer timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
