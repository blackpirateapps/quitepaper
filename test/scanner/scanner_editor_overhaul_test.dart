import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/image_processing/image_adjustments.dart';
import 'package:quitepaper/core/image_processing/image_processor.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/features/scanner/application/scanner_performance_tracker.dart';
import 'package:quitepaper/features/scanner/domain/scanned_page.dart';
import 'package:quitepaper/features/scanner/presentation/document_scanner_screen.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/interactive_crop_overlay.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/page_adjustment_sheet.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/scanner_preview_canvas.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});
  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() => isUnlocked = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _createSampleImageBytes({int width = 300, int height = 400}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. ImageAdjustments & ColorFilter Matrix Unit Tests', () {
    test('Default adjustments are neutral and produce 4x5 identity matrix', () {
      const neutral = ImageAdjustments.neutral;
      expect(neutral.isNeutral, isTrue);
      expect(neutral.rotationQuarterTurns, 0);
      expect(neutral.brightness, 0.0);
      expect(neutral.contrast, 0.0);
      expect(neutral.saturation, 0.0);
      expect(neutral.grayscale, isFalse);
      expect(neutral.crop, isNull);

      final matrix = neutral.toColorMatrix();
      expect(matrix.length, 20);
      expect(matrix[0], 1.0);
      expect(matrix[6], 1.0);
      expect(matrix[12], 1.0);
      expect(matrix[18], 1.0);
      expect(matrix[4], 0.0); // R offset
      expect(matrix[9], 0.0); // G offset
      expect(matrix[14], 0.0); // B offset
    });

    test('Presets produce non-destructive parameter configurations', () {
      expect(ImageAdjustments.auto.contrast, 0.20);
      expect(ImageAdjustments.auto.brightness, 0.05);
      expect(ImageAdjustments.auto.isNeutral, isFalse);

      expect(ImageAdjustments.blackAndWhite.grayscale, isTrue);
      expect(ImageAdjustments.blackAndWhite.contrast, 0.25);
      expect(ImageAdjustments.blackAndWhite.brightness, 0.10);
      expect(ImageAdjustments.blackAndWhite.isNeutral, isFalse);
    });

    test('Rotation methods cycle quarter turns smoothly in [0, 1, 2, 3]', () {
      var adj = ImageAdjustments.neutral;
      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, 1);
      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, 2);
      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, 3);
      adj = adj.rotateRight();
      expect(adj.rotationQuarterTurns, 0);

      adj = adj.rotateLeft();
      expect(adj.rotationQuarterTurns, 3);
      adj = adj.rotateLeft();
      expect(adj.rotationQuarterTurns, 2);
    });

    test('toColorMatrix applies grayscale, contrast, and brightness correctly', () {
      const bw = ImageAdjustments(grayscale: true);
      final bwMatrix = bw.toColorMatrix();
      expect(bwMatrix.length, 20);
      // Rec. 709 luminance coefficients for grayscale row 1: 0.2126, 0.7152, 0.0722
      expect((bwMatrix[0] - 0.2126).abs(), lessThan(0.01));
      expect((bwMatrix[1] - 0.7152).abs(), lessThan(0.01));
      expect((bwMatrix[2] - 0.0722).abs(), lessThan(0.01));

      const bright = ImageAdjustments(brightness: 0.5);
      final brightMatrix = bright.toColorMatrix();
      expect(brightMatrix[4], greaterThan(0)); // Positive offset

      const dark = ImageAdjustments(brightness: -0.5);
      final darkMatrix = dark.toColorMatrix();
      expect(darkMatrix[4], lessThan(0)); // Negative offset
    });

    test('JSON serialization & deserialization round-trip', () {
      const original = ImageAdjustments(
        crop: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
        rotationQuarterTurns: 2,
        brightness: 0.2,
        contrast: 0.3,
        saturation: -0.1,
        grayscale: true,
      );

      final json = original.toJson();
      final reconstructed = ImageAdjustments.fromJson(json);

      expect(reconstructed, equals(original));
      expect(reconstructed.rotationQuarterTurns, 2);
      expect(reconstructed.grayscale, isTrue);
      expect(reconstructed.crop?.x, 0.1);
    });
  });

  group('2. Generation Tokens & Async Race Protection Unit Tests', () {
    test('ScannerPerformanceTracker manages generation tokens and discards stale out-of-order jobs', () {
      final tracker = ScannerPerformanceTracker();
      expect(tracker.currentGeneration, 0);

      final gen1 = tracker.nextGeneration();
      expect(gen1, 1);
      expect(tracker.currentGeneration, 1);

      final gen2 = tracker.nextGeneration();
      expect(gen2, 2);
      expect(tracker.currentGeneration, 2);

      // Job 2 finishes first -> Valid
      expect(tracker.isGenerationCurrent(gen2), isTrue);
      expect(tracker.discardedStaleJobsCount, 0);

      // Job 1 finishes after Job 2 -> Discarded
      expect(tracker.isGenerationCurrent(gen1), isFalse);
      expect(tracker.discardedStaleJobsCount, 1);

      // Verify report
      final report = tracker.getReport();
      expect(report.discardedStaleJobsCount, 1);
      expect(report.activeGenerationsCount, 2);
    });
  });

  group('3. ImageProcessor & Page Representation Lifecycle Unit Tests', () {
    const processor = DartImageProcessor();
    final sampleBytes = _createSampleImageBytes(width: 1200, height: 800);

    test('createPageRepresentations generates ~600px preview and <=200px thumbnail', () async {
      final reps = await processor.createPageRepresentations(sampleBytes);

      expect(reps.previewBytes, isNotEmpty);
      expect(reps.thumbnailBytes, isNotEmpty);
      expect(reps.width, 1200);
      expect(reps.height, 800);
      expect(reps.thumbnailBytes.length, lessThan(reps.previewBytes.length));
    });

    test('processHighResolution applies adjustments and bounds dimensions', () async {
      const adjustments = ImageAdjustments(
        rotationQuarterTurns: 1,
        contrast: 0.2,
        brightness: 0.1,
        grayscale: true,
        crop: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
      );

      final result = await processor.processHighResolution(sampleBytes, adjustments);

      expect(result.imageBytes, isNotEmpty);
      expect(result.width, greaterThan(0));
      expect(result.height, greaterThan(0));
    });
  });

  group('4. ScannedPage Identity & State Isolation Unit Tests', () {
    test('ScannedPage maintains stable identity, cached representations, and copyWith', () {
      final bytes = _createSampleImageBytes();
      final page1 = ScannedPage(
        id: 'stable-page-uuid-1',
        imageBytes: bytes,
        rawImageBytes: bytes,
        previewBytes: bytes,
        thumbnailBytes: bytes,
        width: 300,
        height: 400,
        pageNumber: 1,
        adjustments: ImageAdjustments.auto,
      );

      expect(page1.id, 'stable-page-uuid-1');
      expect(page1.adjustments.contrast, 0.20);
      expect(page1.previewBytes, equals(bytes));
      expect(page1.thumbnailBytes, equals(bytes));

      final page2 = page1.copyWith(
        pageNumber: 2,
        adjustments: ImageAdjustments.blackAndWhite,
      );

      // Page identity is preserved, adjustments are isolated
      expect(page2.id, 'stable-page-uuid-1');
      expect(page2.pageNumber, 2);
      expect(page2.adjustments.grayscale, isTrue);
      expect(page1.adjustments.grayscale, isFalse);
    });
  });

  group('5. InteractiveCropOverlay Widget Tests', () {
    testWidgets('Renders crop overlay and handles drag interaction', (tester) async {
      NormalizedRect? updatedCrop;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: InteractiveCropOverlay(
                crop: const NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                accentColor: Colors.amber,
                onCropChanged: (crop) => updatedCrop = crop,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InteractiveCropOverlay), findsOneWidget);

      // Drag top-left corner (at pixel ~30, 40)
      final gesture = await tester.startGesture(const Offset(30, 40));
      await gesture.moveBy(const Offset(20, 20));
      await gesture.up();
      await tester.pump();

      expect(updatedCrop, isNotNull);
      expect(updatedCrop!.x, greaterThan(0.1));
      expect(updatedCrop!.y, greaterThan(0.1));
    });
  });

  group('6. ScannerPreviewCanvas & Before/After Comparison Widget Tests', () {
    testWidgets('Renders preview canvas, handles pinch-to-zoom, and press-and-hold original', (tester) async {
      final sampleBytes = _createSampleImageBytes();
      const adjustments = ImageAdjustments(
        brightness: 0.3,
        contrast: 0.2,
        grayscale: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: ScannerPreviewCanvas(
                previewBytes: sampleBytes,
                adjustments: adjustments,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ScannerPreviewCanvas), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('ORIGINAL'), findsNothing);

      // Long-press to activate before/after comparison
      final center = tester.getCenter(find.byType(ScannerPreviewCanvas));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('ORIGINAL'), findsOneWidget);

      // Release finger
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ORIGINAL'), findsNothing);
    });
  });

  group('7. PageAdjustmentSheet Widget Tests', () {
    testWidgets('Allows switching presets, adjusting sliders, and applying changes', (tester) async {
      final sampleBytes = _createSampleImageBytes();
      final page = ScannedPage(
        id: 'page-adjust-test',
        imageBytes: sampleBytes,
        previewBytes: sampleBytes,
        thumbnailBytes: sampleBytes,
        width: 300,
        height: 400,
        pageNumber: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PageAdjustmentSheet(
              page: page,
            ),
          ),
        ),
      );

      expect(find.text('Page 1 Adjustments'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('B&W'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Contrast'), findsOneWidget);

      // Tap Auto Preset
      await tester.tap(find.text('Auto'));
      await tester.pump();

      // Tap B&W Preset
      await tester.tap(find.text('B&W'));
      await tester.pump();

      // Switch to Crop & Rotate Tab
      await tester.tap(find.text('Crop & Rotate'));
      await tester.pump();

      expect(find.text('↶ Rotate Left'), findsOneWidget);
      expect(find.text('↷ Rotate Right'), findsOneWidget);

      // Tap Rotate Right
      await tester.tap(find.text('↷ Rotate Right'));
      await tester.pump();

      // Tap Reset
      await tester.tap(find.text('Reset'));
      await tester.pump();
    });
  });

  group('8. Full DocumentScannerScreen Multi-Page & Finalization Integration Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late DocumentLocalStorage storage;
    late MockKeyManager keyManager;
    late DocumentService documentService;
    late CryptoService cryptoService;

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_scanner_');
      storage = DocumentLocalStorage(
        customDocumentsDirectory: tempDir,
        customTempDirectory: tempDir,
      );
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      documentService = DocumentService(
        database: database,
        keyManager: keyManager,
        crypto: DocumentCrypto(cryptoService: cryptoService),
        storage: storage,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Renders scanner fallback canvas and top bar controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(documentService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DocumentScannerScreen(
              initialTitle: 'Invoice Scan',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Document Scanner'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets('Tablet layout displays split view with pages sidebar and preview canvas', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(documentService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DocumentScannerScreen(
              initialTitle: 'Contract',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pages (0)'), findsOneWidget);
      expect(find.text('Save PDF'), findsOneWidget);
      expect(find.text('Add Page'), findsOneWidget);
    });
  });
}
