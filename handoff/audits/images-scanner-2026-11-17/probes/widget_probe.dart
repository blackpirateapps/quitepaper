// Historical characterization probes; intentionally assert baseline defects.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/presentation/image_viewer_modal.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_asset_image_view.dart';
import 'package:quitepaper/core/attachments/presentation/viewer_image_item.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/scan_mode.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/scanner/presentation/document_scanner_screen.dart';
import 'package:quitepaper/features/scanner/domain/scanned_page.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/page_adjustment_sheet.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/scanner_preview_canvas.dart';

Uint8List fixture() {
  final image = img.Image(width: 120, height: 80);
  img.fill(image, color: img.ColorRgb8(80, 120, 180));
  return Uint8List.fromList(img.encodePng(image));
}

class AuditPicker extends FilePicker {
  Uint8List? picked;
  Completer<FilePickerResult?>? pending;
  String? output;
  Uint8List? savedBytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    if (pending != null) return pending!.future;
    return FilePickerResult([
      PlatformFile(name: 'page.png', size: picked!.length, bytes: picked),
    ]);
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedBytes = bytes;
    return output;
  }
}

class ProbeProcessor implements ImageProcessor {
  Completer<({NormalizedQuad quad, double confidence})>? detection;
  int preparations = 0;
  @override
  Future<PageRepresentations> createPageRepresentations(Uint8List bytes) async {
    preparations++;
    return (previewBytes: bytes, thumbnailBytes: bytes, width: 120, height: 80);
  }

  @override
  Future<Map<ScanMode, Uint8List>> renderModePreviews(
    Uint8List bytes, {
    List<ScanMode> modes = ScanMode.values,
    int maxDimension = 600,
  }) async => {for (final mode in modes) mode: bytes};
  @override
  Future<({NormalizedQuad quad, double confidence})> detectDocumentQuad(
    Uint8List bytes,
  ) async => detection != null
      ? await detection!.future
      : (quad: NormalizedQuad.full, confidence: 0.0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ModeProcessor extends ProbeProcessor {
  ModeProcessor(this.monochrome);
  final Uint8List monochrome;
  @override
  Future<Map<ScanMode, Uint8List>> renderModePreviews(
    Uint8List bytes, {
    List<ScanMode> modes = ScanMode.values,
    int maxDimension = 600,
  }) async => {
    for (final mode in modes) mode: mode.isMonochrome ? monochrome : bytes,
  };
}

class ProbeAssets implements AttachmentService {
  ProbeAssets(this.bytes);
  final Uint8List bytes;
  bool locked = false;
  int calls = 0;
  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String id, {
    String variant = 'original',
  }) async {
    calls++;
    return locked
        ? ResourceResolution.locked(QuietPaperUri.asset(id))
        : ResourceResolution.available(QuietPaperUri.asset(id), bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PendingAssets extends ProbeAssets {
  PendingAssets() : super(fixture());
  final requests = <String, Completer<ResourceResolution<Uint8List>>>{};
  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String id, {
    String variant = 'original',
  }) {
    return (requests[id] = Completer<ResourceResolution<Uint8List>>()).future;
  }
}

Widget app(Widget child, {ProbeProcessor? processor, ProbeAssets? assets}) =>
    ProviderScope(
      overrides: [
        if (processor != null)
          imageProcessorProvider.overrideWithValue(processor),
        if (assets != null) attachmentServiceProvider.overrideWithValue(assets),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FilePicker.platform = AuditPicker());

  testWidgets('IS-02 review canvas ignores applied rectangular crop', (
    tester,
  ) async {
    final bytes = fixture();
    await tester.pumpWidget(
      app(
        ScannerPreviewCanvas(
          previewBytes: bytes,
          adjustments: const ImageAdjustments(
            crop: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1),
          ),
        ),
      ),
    );
    await frames(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as MemoryImage).bytes, bytes);
    // No geometry transform/crop in the review subtree. Same image layout as
    // neutral despite half-width crop. Actual final processing verified below.
    final croppedSize = tester.getSize(find.byType(Image));
    expect(croppedSize.width, greaterThan(0));
    await tester.pumpWidget(
      app(
        ScannerPreviewCanvas(
          previewBytes: bytes,
          adjustments: ImageAdjustments.neutral,
        ),
      ),
    );
    await frames(tester);
    expect(tester.getSize(find.byType(Image)), croppedSize);
    final result = await tester.runAsync(
      () => const DartImageProcessor().processHighResolution(
        bytes,
        const ImageAdjustments(
          crop: NormalizedRect(x: 0, y: 0, width: 0.5, height: 1),
        ),
      ),
    );
    expect(result!.width, 60);
    debugPrint(
      'IS-02 review size unchanged=$croppedSize, exported image=60x80',
    );
  });

  for (final existing in [false, true]) {
    testWidgets('IS-04 desktop Save Image no write (existing=$existing)', (
      tester,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('qp-image-audit-'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/output.png');
      if (existing) await tester.runAsync(() => file.writeAsBytes([1, 2, 3]));
      final picker = AuditPicker()..output = file.path;
      FilePicker.platform = picker;
      final bytes = fixture();
      final buildErrors = <Object>[];
      await runZonedGuarded(() async {
        await tester.pumpWidget(
          app(
            ImageViewerModal(
              images: [
                ViewerImageItem(
                  url: 'https://audit.invalid/supplied.png',
                  initialBytes: bytes,
                ),
              ],
            ),
          ),
        );
        await tester.pump();
      }, (error, stack) => buildErrors.add(error));
      expect(buildErrors, hasLength(1));
      expect(buildErrors.single.toString(), contains('called during build'));
      debugPrint(
        'IS-13 preloaded network viewer emitted build-phase setState diagnostic',
      );
      await frames(tester);
      await tester.tap(find.text('Save Image'));
      await frames(tester);
      expect(find.text('Image saved successfully'), findsOneWidget);
      expect(picker.savedBytes, bytes);
      if (existing) {
        expect(await tester.runAsync(() => file.readAsBytes()), [1, 2, 3]);
      } else {
        expect(await tester.runAsync(() => file.exists()), isFalse);
      }
      debugPrint(
        'IS-04 success UI despite existing=$existing and no image write',
      );
    });
  }

  testWidgets('IS-06 delayed auto-detection overwrites committed Full Page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final detector = Completer<({NormalizedQuad quad, double confidence})>();
    final processor = ProbeProcessor()..detection = detector;
    FilePicker.platform = AuditPicker()..picked = fixture();
    await tester.pumpWidget(
      app(const DocumentScannerScreen(), processor: processor),
    );
    await frames(tester);
    await tester.tap(find.byTooltip('Import from files'));
    await frames(tester);
    expect(find.text('Pages (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Adjust page'));
    await frames(tester);
    await tester.tap(find.text('Crop & Rotate'));
    await frames(tester);
    await tester.tap(find.text('Use Full Page'));
    await tester.tap(find.text('Apply'));
    await frames(tester);
    // Verify the manual choice committed before releasing stale work.
    await tester.tap(find.byTooltip('Adjust page'));
    await frames(tester);
    expect(
      tester
          .widget<PageAdjustmentSheet>(find.byType(PageAdjustmentSheet))
          .page
          .documentQuad,
      isNull,
    );
    await tester.tap(find.text('Apply'));
    await frames(tester);
    final detected = NormalizedQuad.fromRect(
      const NormalizedRect(x: .1, y: .1, width: .8, height: .8),
    );
    detector.complete((quad: detected, confidence: .9));
    await frames(tester);
    expect(
      tester
          .widget<ScannerPreviewCanvas>(find.byType(ScannerPreviewCanvas))
          .quad,
      isNull,
    );
    await tester.tap(find.byTooltip('Adjust page'));
    await frames(tester);
    final current = tester.widget<PageAdjustmentSheet>(
      find.byType(PageAdjustmentSheet),
    );
    expect(current.page.documentQuad, detected);
    debugPrint(
      'IS-06 Full Page was committed, then replaced by stale detector result',
    );
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  });

  testWidgets(
    'IS-09 cached plaintext still displays when service becomes locked',
    (tester) async {
      final service = ProbeAssets(fixture());
      const id = 'audit-lock-cache-unique';
      await tester.pumpWidget(
        app(const QuietAssetImageView(assetId: id), assets: service),
      );
      await frames(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox());
      service.locked = true;
      await tester.pumpWidget(
        app(const QuietAssetImageView(assetId: id), assets: service),
      );
      await frames(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Encrypted image locked'), findsNothing);
      expect(service.calls, 1);
      debugPrint(
        'IS-09 cached asset renders while resolver is locked, resolve calls=1',
      );
    },
  );

  testWidgets(
    'IS-10 200 unmounted image sources are all retained after engine eviction',
    (tester) async {
      final service = ProbeAssets(fixture());
      for (var i = 0; i < 200; i++) {
        await tester.pumpWidget(
          app(
            QuietAssetImageView(
              key: ValueKey(i),
              assetId: 'audit-retention-$i',
            ),
            assets: service,
          ),
        );
        await tester.pump();
      }
      expect(service.calls, 200);
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      service.locked = true;
      for (var i = 0; i < 200; i++) {
        await tester.pumpWidget(
          app(
            QuietAssetImageView(
              key: ValueKey(i),
              assetId: 'audit-retention-$i',
            ),
            assets: service,
          ),
        );
        await tester.pump();
        expect(find.byType(Image), findsOneWidget);
      }
      expect(service.calls, 200);
      debugPrint(
        'IS-10 all 200 distinct sources survive unmount and Flutter image cache clear',
      );
    },
  );

  testWidgets('IS-11 stale resolution replaces the new source pixels', (
    tester,
  ) async {
    final service = PendingAssets();
    final bytesA = fixture();
    final blue = img.Image(width: 160, height: 120);
    img.fill(blue, color: img.ColorRgb8(0, 0, 255));
    final bytesB = Uint8List.fromList(img.encodePng(blue));
    const idA = 'audit-stale-A';
    const idB = 'audit-stale-B';
    const key = ValueKey('reuse-one-image-state');
    await tester.pumpWidget(
      app(
        const QuietAssetImageView(key: key, assetId: idA),
        assets: service,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      app(
        const QuietAssetImageView(key: key, assetId: idB),
        assets: service,
      ),
    );
    await tester.pump();
    service.requests[idB]!.complete(
      ResourceResolution.available(QuietPaperUri.asset(idB), bytesB),
    );
    await frames(tester);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      bytesB,
    );
    service.requests[idA]!.complete(
      ResourceResolution.available(QuietPaperUri.asset(idA), bytesA),
    );
    await frames(tester);
    expect(
      tester
          .widget<QuietAssetImageView>(find.byType(QuietAssetImageView))
          .assetId,
      idB,
    );
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      bytesA,
    );
    debugPrint('IS-11 current widget asset=B, actual displayed MemoryImage=A');
  });

  testWidgets('IS-14 ORIGINAL comparison keeps the monochrome mode bitmap', (
    tester,
  ) async {
    final original = fixture();
    final mono = Uint8List.fromList(
      img.encodePng(img.grayscale(img.decodePng(original)!)),
    );
    await tester.pumpWidget(
      app(
        PageAdjustmentSheet(
          page: ScannedPage(
            id: 'compare',
            imageBytes: original,
            width: 120,
            height: 80,
            pageNumber: 1,
            scanMode: ScanMode.blackAndWhite,
          ),
          imageProcessor: ModeProcessor(mono),
        ),
      ),
    );
    await frames(tester);
    final canvas = find.byType(ScannerPreviewCanvas);
    final mainImage = find.descendant(of: canvas, matching: find.byType(Image));
    expect((tester.widget<Image>(mainImage).image as MemoryImage).bytes, mono);
    final gesture = await tester.startGesture(tester.getCenter(canvas));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect((tester.widget<Image>(mainImage).image as MemoryImage).bytes, mono);
    expect(
      (tester.widget<Image>(mainImage).image as MemoryImage).bytes,
      isNot(original),
    );
    await gesture.up();
    await frames(tester);
    debugPrint(
      'IS-14 ORIGINAL badge is visible but MemoryImage still contains monochrome bytes',
    );
  });

  testWidgets('late gallery callback after disposal is observed', (
    tester,
  ) async {
    final pending = Completer<FilePickerResult?>();
    FilePicker.platform = AuditPicker()..pending = pending;
    final processor = ProbeProcessor();
    await tester.pumpWidget(
      app(const DocumentScannerScreen(), processor: processor),
    );
    await frames(tester);
    await tester.tap(find.byTooltip('Import from files'));
    await frames(tester);
    await tester.pumpWidget(const SizedBox());
    final bytes = fixture();
    pending.complete(
      FilePickerResult([
        PlatformFile(name: 'late.png', size: bytes.length, bytes: bytes),
      ]),
    );
    await frames(tester);
    // _importPageFromGallery catches and prints the setState-after-dispose
    // exception; preserve that actual diagnostic in the audit log.
    expect(processor.preparations, 0);
  });
}
