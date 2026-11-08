import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';
import 'package:quitepaper/core/pdf/syncfusion_pdf_page_renderer.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

class FakePdfViewerPlatform extends PdfViewerPlatform {
  String? lastLoadedPath;
  String? lastLoadedDocId;
  String? lastClosedDocId;
  int pageCountToReturn = 2;
  List<double> heightsToReturn = [842.0, 842.0];
  List<double> widthsToReturn = [595.0, 595.0];
  final List<({int pageNumber, int width, int height, String docId})>
      getPageCalls = [];
  bool shouldThrowOnLoad = false;

  @override
  Future<String?> loadPdfFromFile(
    String path,
    String documentID, [
    String? password,
  ]) async {
    if (shouldThrowOnLoad) {
      throw Exception('Simulated load error');
    }
    lastLoadedPath = path;
    lastLoadedDocId = documentID;
    return pageCountToReturn.toString();
  }

  @override
  Future<List?> getPagesHeight(String documentID) async => heightsToReturn;

  @override
  Future<List?> getPagesWidth(String documentID) async => widthsToReturn;

  @override
  Future<Uint8List?> getPage(
    int pageNumber,
    int width,
    int height,
    String documentID,
  ) async {
    getPageCalls.add((
      pageNumber: pageNumber,
      width: width,
      height: height,
      docId: documentID,
    ));
    // Return valid RGBA buffer: width * height * 4 bytes
    return Uint8List(width * height * 4);
  }

  @override
  Future<void> closeDocument(String documentID) async {
    lastClosedDocId = documentID;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePdfViewerPlatform fakePlatform;
  late Directory tempTestDir;

  setUp(() async {
    fakePlatform = FakePdfViewerPlatform();
    tempTestDir = await Directory.systemTemp.createTemp('syncfusion_test_');
  });

  tearDown(() async {
    try {
      if (await tempTestDir.exists()) {
        await tempTestDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('SyncfusionPdfPageRenderer Tests', () {
    test('renders all pages and encodes PNGs properly', () async {
      final renderer = SyncfusionPdfPageRenderer(
        platform: fakePlatform,
        customTempDirectory: tempTestDir,
      );

      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
      final results = await renderer.renderPages(dummyPdfBytes, dpi: 72.0);

      expect(results.length, equals(2));
      expect(results[0].pageNumber, equals(1));
      expect(results[0].width, equals(595));
      expect(results[0].height, equals(842));
      // First 8 bytes of PNG header: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
      expect(results[0].imageBytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));

      expect(results[1].pageNumber, equals(2));
      expect(results[1].imageBytes.isNotEmpty, isTrue);

      // Verify closeDocument was called
      expect(fakePlatform.lastClosedDocId, isNotNull);
      expect(fakePlatform.lastClosedDocId, equals(fakePlatform.lastLoadedDocId));

      // Verify temp files were deleted
      final remainingFiles = await tempTestDir.list().toList();
      expect(remainingFiles.isEmpty, isTrue);
    });

    test('renders specific single page using 1-based page index to platform', () async {
      final renderer = SyncfusionPdfPageRenderer(
        platform: fakePlatform,
        customTempDirectory: tempTestDir,
      );

      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final page = await renderer.renderSinglePage(dummyPdfBytes, 1, dpi: 72.0);

      expect(page, isNotNull);
      expect(page!.pageNumber, equals(2));
      expect(fakePlatform.getPageCalls.length, equals(1));
      expect(fakePlatform.getPageCalls.first.pageNumber, equals(2));
    });

    test('returns empty list for empty pdfBytes without error', () async {
      final renderer = SyncfusionPdfPageRenderer(
        platform: fakePlatform,
        customTempDirectory: tempTestDir,
      );

      final results = await renderer.renderPages(Uint8List(0));
      expect(results, isEmpty);
      expect(fakePlatform.lastLoadedPath, isNull);
    });

    test('cleans up resources and returns empty list on platform load error', () async {
      fakePlatform.shouldThrowOnLoad = true;

      final renderer = SyncfusionPdfPageRenderer(
        platform: fakePlatform,
        customTempDirectory: tempTestDir,
      );

      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final results = await renderer.renderPages(dummyPdfBytes);

      expect(results, isEmpty);
      expect(fakePlatform.lastClosedDocId, isNotNull);
      final remainingFiles = await tempTestDir.list().toList();
      expect(remainingFiles.isEmpty, isTrue);
    });

    test('DefaultPdfPageRenderer delegates to desktopRenderer on desktop platforms', () async {
      final desktopRenderer = SyncfusionPdfPageRenderer(
        platform: fakePlatform,
        customTempDirectory: tempTestDir,
      );
      final defaultRenderer = DefaultPdfPageRenderer(
        desktopRenderer: desktopRenderer,
      );

      final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      final single = await defaultRenderer.renderSinglePage(dummyPdfBytes, 0);

      if (Platform.isLinux || Platform.isWindows) {
        expect(single, isNotNull);
        expect(fakePlatform.getPageCalls.isNotEmpty, isTrue);
      }
    });
  });
}
