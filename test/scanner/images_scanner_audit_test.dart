import 'dart:async';
import 'dart:typed_data';
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
