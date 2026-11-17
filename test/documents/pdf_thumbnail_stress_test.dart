import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

class _Keys implements KeyManager {
  final _key = Uint8List.fromList(List.generate(32, (i) => i + 1));
  @override
  Uint8List getMasterKey() => _key;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Renderer implements PdfPageRenderer {
  final calls = <int, int>{};
  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150,
  }) async {
    calls.update(pageIndex, (count) => count + 1, ifAbsent: () => 1);
    await Future<void>.delayed(Duration.zero);
    return RenderedPage(
      pageNumber: pageIndex + 1,
      imageBytes: Uint8List.fromList([137, 80, 78, 71, pageIndex]),
      width: 1,
      height: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '2500 requests deduplicate 250 pages and survive encrypted disk reload',
    () async {
      final directory = await Directory.systemTemp.createTemp('qp-pdf-stress-');
      addTearDown(() => directory.delete(recursive: true));
      final keys = _Keys();
      final renderer = _Renderer();
      final service = PdfThumbnailService(
        keyManager: keys,
        renderer: renderer,
        customDirectory: directory,
      );
      final pdf = Uint8List.fromList([37, 80, 68, 70]);
      final results = await Future.wait(
        List.generate(
          2500,
          (i) => service.getPageThumbnail(
            documentId: 'stress-document',
            pageIndex: i % 250,
            pdfBytes: pdf,
          ),
        ),
      );
      await service.flushPendingWrites();
      expect(renderer.calls.length, 250);
      expect(renderer.calls.values, everyElement(1));
      for (var i = 0; i < results.length; i++) {
        expect(results[i], [137, 80, 78, 71, i % 250]);
      }

      final diskRenderer = _Renderer();
      final restarted = PdfThumbnailService(
        keyManager: keys,
        renderer: diskRenderer,
        customDirectory: directory,
      );
      final reloaded = await Future.wait(
        List.generate(
          250,
          (i) => restarted.getPageThumbnail(
            documentId: 'stress-document',
            pageIndex: i,
            pdfBytes: pdf,
          ),
        ),
      );
      expect(diskRenderer.calls, isEmpty);
      for (var i = 0; i < reloaded.length; i++) {
        expect(reloaded[i], [137, 80, 78, 71, i]);
      }
      final diskFile = File(
        '${directory.path}/pdf_thumbnails/stress-document/page_0.qpthumb',
      );
      expect(
        await diskFile.readAsBytes(),
        isNot(orderedEquals(results.first!)),
      );

      await restarted.deleteThumbnails('stress-document');
      expect(
        await restarted.hasDiskThumbnail(
          documentId: 'stress-document',
          pageIndex: 0,
        ),
        isFalse,
      );
    },
  );
}
