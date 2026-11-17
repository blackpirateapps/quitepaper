import 'dart:async';
import 'dart:convert';
import 'package:quitepaper/core/attachments/presentation/quiet_asset_image_view.dart';
import 'package:quitepaper/features/scanner/presentation/document_scanner_screen.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/page_adjustment_sheet.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:quitepaper/core/attachments/presentation/image_viewer_modal.dart';
import 'package:quitepaper/core/attachments/presentation/viewer_image_item.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/image_processing/scan_mode.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
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
  testWidgets('IS-12 late gallery callback after disposal is ignored', (
    tester,
  ) async {
    final messages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) { messages.add(message ?? ''); };
    addTearDown(() => debugPrint = originalDebugPrint);
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
    expect(processor.preparations, 0);
    expect(messages.join('\n'), isNot(contains('after dispose')));
    expect(tester.takeException(), isNull);
    debugPrint = originalDebugPrint;
  });
  for (final staleFailure in [false, true]) {
    for (final oldFirst in [false, true]) {
      testWidgets('IS-11 source switch ignores stale load (failure=$staleFailure oldFirst=$oldFirst)', (tester) async {
        final service = PendingAssets();
        const key = ValueKey('shared-image');
        final bytesA = fixture();
        final imageB = img.Image(width: 160, height: 120);
        final bytesB = Uint8List.fromList(img.encodePng(imageB));
        await tester.pumpWidget(app(const QuietAssetImageView(key: key, assetId: 'A'), assets: service));
        await tester.pump();
        await tester.pumpWidget(app(const QuietAssetImageView(key: key, assetId: 'B'), assets: service));
        await tester.pump();
        void finishOld() {
          if (staleFailure) {
            service.requests['A']!.completeError(StateError('old failure'));
          } else {
            service.requests['A']!.complete(ResourceResolution.available(QuietPaperUri.asset('A'), bytesA));
          }
        }
        if (oldFirst) {
          finishOld();
          await frames(tester);
          expect(find.byType(Image), findsNothing);
          expect(find.textContaining('retry'), findsNothing);
        }
        service.requests['B']!.complete(ResourceResolution.available(QuietPaperUri.asset('B'), bytesB));
        await frames(tester);
        if (!oldFirst) { finishOld(); await frames(tester); }
        expect((tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes, bytesB);
        expect(tester.getSize(find.byType(Image)), const Size(160, 120));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('IS-11 variant switches invalidate old loads of the same asset', (tester) async {
    final service = PendingAssets();
    const key = ValueKey('variant-image');
    await tester.pumpWidget(app(const QuietAssetImageView(key: key, assetId: 'same', variant: 'thumbnail'), assets: service));
    final first = service.requests['same']!;
    await tester.pumpWidget(app(const QuietAssetImageView(key: key, assetId: 'same'), assets: service));
    final bytes = fixture();
    service.requests['same']!.complete(ResourceResolution.available(QuietPaperUri.asset('same'), bytes));
    await frames(tester);
    first.complete(ResourceResolution.locked(QuietPaperUri.asset('same')));
    await frames(tester);
    expect((tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes, bytes);
  });
  testWidgets('IS-10 data URL source buffers are released between mounts', (tester) async {
    final url = 'data:image/png;base64,${base64Encode(fixture())}';
    await tester.pumpWidget(app(QuietAssetImageView(url: url)));
    await frames(tester);
    final first = (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await tester.pumpWidget(app(QuietAssetImageView(url: url)));
    await frames(tester);
    final second = (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;
    expect(second, first);
    expect(identical(second, first), isFalse);
  });
  testWidgets('IS-10 unmounted inline sources are resolved again instead of retained globally', (tester) async {
    final service = ProbeAssets(fixture());
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < 200; i++) {
        await tester.pumpWidget(app(QuietAssetImageView(
          key: ValueKey('$pass-$i'), assetId: 'retention-$i'), assets: service));
        await tester.pump();
      }
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      expect(service.calls, (pass + 1) * 200);
    }
  });
  testWidgets(
    'IS-09 cached plaintext cannot bypass a locked resolver',
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
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Encrypted image locked'), findsOneWidget);
      expect(service.calls, 2);
      debugPrint(
        'IS-09 locked resolver is consulted again',
      );
    },
  );

  testWidgets('IS-06 delayed auto-detection preserves committed Full Page', (
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
    expect(current.page.documentQuad, isNull);
    debugPrint(
      'IS-06 Full Page survives the stale detector result',
    );
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
  });

  for (final destination in ['new', 'overwrite', 'cancel', 'empty', 'failure']) {
    testWidgets('IS-04 desktop image save $destination', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final directory = (await tester.runAsync(() => Directory.systemTemp.createTemp('qp-image-fix-')))!;
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/output.png');
      if (destination == 'overwrite') {
        await tester.runAsync(() => file.writeAsBytes(List.filled(10000, 9)));
      }
      final picker = AuditPicker()..output = switch (destination) {
        'cancel' => null, 'empty' => '', 'failure' => directory.path, _ => file.path,
      };
      FilePicker.platform = picker;
      final bytes = fixture();
      final buildErrors = <Object>[];
      // IS-13 is addressed separately; retain its known diagnostic for now.
      await runZonedGuarded(() async {
        await tester.pumpWidget(app(ImageViewerModal(images: [
          ViewerImageItem(url: 'https://fixture.invalid/image.png', initialBytes: bytes),
        ])));
        await tester.pump();
      }, (error, stack) => buildErrors.add(error));
      expect(buildErrors, hasLength(1));
      expect(buildErrors.single.toString(), contains('called during build'));
      await frames(tester);
      await tester.tap(find.text('Save Image'));
      for (var i = 0; i < 20; i++) {
        await frames(tester);
        if (find.text('Image saved successfully').evaluate().isNotEmpty ||
            find.textContaining('Failed to save image').evaluate().isNotEmpty) { break; }
      }
      if (destination == 'new' || destination == 'overwrite') {
        expect(await tester.runAsync(() => file.readAsBytes()), bytes);
        expect(find.text('Image saved successfully'), findsOneWidget);
      } else {
        expect(find.text('Image saved successfully'), findsNothing);
        if (destination == 'failure') {
          expect(find.textContaining('Failed to save image'), findsOneWidget);
        } else {
          expect(await tester.runAsync(() => file.exists()), isFalse);
        }
      }
      debugDefaultTargetPlatformOverride = null;
    });
  }
  testWidgets('IS-02 review renders applied rectangle and quad framing', (tester) async {
    final bytes = fixture();
    for (final perspective in [false, true]) {
      const crop = NormalizedRect(x: 0, y: 0, width: .5, height: 1);
      await tester.pumpWidget(app(ScannerPreviewCanvas(
        key: ValueKey(perspective), previewBytes: bytes,
        adjustments: perspective ? ImageAdjustments.neutral : const ImageAdjustments(crop: crop),
        quad: perspective ? NormalizedQuad.fromRect(crop) : null,
      )));
      for (var i = 0; i < 40 && find.byType(Image).evaluate().isEmpty; i++) {
        await frames(tester);
      }
      final image = tester.widget<Image>(find.byType(Image));
      final decoded = img.decodeImage((image.image as MemoryImage).bytes)!;
      expect(decoded.width / decoded.height, closeTo(.75, .03));
      expect(decoded.width, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    }
  });
}
