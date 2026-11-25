import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';
import 'pdf_thumbnail_service_test.dart' show MockKeyManager;

class GatedRenderer extends Fake implements PdfPageRenderer {
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150,
  }) async {
    calls++;
    if (pdfBytes.last == 1) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    return RenderedPage(
      pageNumber: 1,
      imageBytes: pdfBytes,
      width: 1,
      height: 1,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deletion invalidates in-flight renders without resurrecting disk cache',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'qp-invalidation-',
      );
      final renderer = GatedRenderer();
      final service = PdfThumbnailService(
        keyManager: MockKeyManager(masterKey: Uint8List(32)),
        renderer: renderer,
        customDirectory: directory,
      );
      addTearDown(() async {
        await service.flushPendingWrites();
        await directory.delete(recursive: true);
      });
      Future<Uint8List?> fetch(String id, int source) =>
          service.getPageThumbnail(
            documentId: id,
            pageIndex: 0,
            pdfBytes: Uint8List.fromList([source]),
          );

      final old = fetch('replaced', 1);
      await renderer.started.future;
      await service.deleteThumbnails('replaced');
      final replacement = fetch('replaced', 2);
      renderer.release.complete();
      expect(await old, isNull);
      expect(await replacement, [2]);
      expect(renderer.calls, 2);
      await service.flushPendingWrites();
      service.invalidateMemoryCache('replaced');
      expect(await fetch('replaced', 2), [2]);
      expect(renderer.calls, 2);
      await service.deleteThumbnails('replaced');
      expect(
        await service.hasDiskThumbnail(documentId: 'replaced', pageIndex: 0),
        isFalse,
      );
    },
  );

  test('deleted document render cannot recreate its directory', () async {
    final directory = await Directory.systemTemp.createTemp('qp-deleted-');
    final renderer = GatedRenderer();
    final service = PdfThumbnailService(
      keyManager: MockKeyManager(masterKey: Uint8List(32)),
      renderer: renderer,
      customDirectory: directory,
    );
    addTearDown(() => directory.delete(recursive: true));
    final old = service.getPageThumbnail(
      documentId: 'deleted',
      pageIndex: 0,
      pdfBytes: Uint8List.fromList([1]),
    );
    await renderer.started.future;
    await service.deleteThumbnails('deleted');
    renderer.release.complete();
    expect(await old, isNull);
    await service.flushPendingWrites();
    expect(
      await (await service.getThumbnailDirectory('deleted')).exists(),
      isFalse,
    );
  });
}
