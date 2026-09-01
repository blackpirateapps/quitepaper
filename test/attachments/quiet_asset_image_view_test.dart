import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/attachment_provider.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/presentation/image_viewer_modal.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_asset_image_view.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';

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

class MockAttachmentService implements AttachmentService {
  MockAttachmentService({required this.mockDataMap});

  final Map<String, Uint8List?> mockDataMap;

  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(String assetId, {String variant = 'original'}) async {
    final uri = QuietPaperUri.asset(assetId);
    if (mockDataMap.containsKey(assetId)) {
      final data = mockDataMap[assetId];
      if (data != null) {
        return ResourceResolution.available(uri, data);
      } else {
        return ResourceResolution.missing(uri);
      }
    }
    return ResourceResolution.missing(uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuietAssetImageView Widget Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late Uint8List testSmallImageBytes;
    late Uint8List testWideImageBytes;
    late Uint8List testTallImageBytes;
    const smallAssetId = 'att-small-1';
    const wideAssetId = 'att-wide-1';
    const tallAssetId = 'att-tall-1';

    setUp(() {
      database = AppDatabase.memory();
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      // Small image: 100x100
      final smallImg = img.Image(width: 100, height: 100);
      img.fill(smallImg, color: img.ColorRgb8(100, 150, 200));
      testSmallImageBytes = Uint8List.fromList(img.encodePng(smallImg));

      // Wide landscape image: 800x200
      final wideImg = img.Image(width: 800, height: 200);
      img.fill(wideImg, color: img.ColorRgb8(200, 100, 100));
      testWideImageBytes = Uint8List.fromList(img.encodePng(wideImg));

      // Tall image: 200x800
      final tallImg = img.Image(width: 200, height: 800);
      img.fill(tallImg, color: img.ColorRgb8(100, 200, 100));
      testTallImageBytes = Uint8List.fromList(img.encodePng(tallImg));
    });

    tearDown(() async {
      await database.close();
    });

    Widget buildTestWidget({
      required Widget child,
      ThemeData? theme,
      Map<String, Uint8List?>? mockData,
    }) {
      final dataMap = mockData ??
          {
            smallAssetId: testSmallImageBytes,
            wideAssetId: testWideImageBytes,
            tallAssetId: testTallImageBytes,
          };

      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          keyManagerProvider.overrideWithValue(keyManager),
          attachmentServiceProvider.overrideWithValue(MockAttachmentService(mockDataMap: dataMap)),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Small image renders at natural size without upscaling and centers', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const QuietAssetImageView(
            assetId: smallAssetId,
            altText: 'Small icon',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageSize = tester.getSize(imageFinder);
      expect(imageSize.width, 100.0);
      expect(imageSize.height, 100.0);
    });

    testWidgets('Wide landscape image scales proportionally to available content width', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const QuietAssetImageView(
            assetId: wideAssetId,
            altText: 'Wide panoramic chart',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageSize = tester.getSize(imageFinder);
      // Available width is 600. Aspect ratio = 800/200 = 4.0. Height = 600 / 4.0 = 150.0
      expect(imageSize.width, 600.0);
      expect(imageSize.height, 150.0);
    });

    testWidgets('Tall image is constrained to maxAllowedHeight preserving aspect ratio', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const QuietAssetImageView(
            assetId: tallAssetId,
            maxHeight: 400.0,
            altText: 'Tall mobile screenshot',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageSize = tester.getSize(imageFinder);
      // Max height = 400. Aspect ratio = 200 / 800 = 0.25. Width = 400 * 0.25 = 100.0
      expect(imageSize.height, 400.0);
      expect(imageSize.width, 100.0);
    });

    testWidgets('Renders caption centered below image when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const QuietAssetImageView(
            assetId: smallAssetId,
            altText: 'Architecture Diagram',
            caption: 'System architecture during load spikes',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('System architecture during load spikes'), findsOneWidget);
    });

    testWidgets('Missing asset renders calm error state with Tap to retry', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          mockData: {'missing-id': null},
          child: const QuietAssetImageView(
            assetId: 'missing-id',
            altText: 'Lost diagram',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Tap to retry'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('Tapping image opens fullscreen ImageViewerModal', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: const QuietAssetImageView(
            assetId: smallAssetId,
            altText: 'Tap to inspect',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Image), warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerModal), findsOneWidget);
      expect(find.text('Tap to inspect'), findsOneWidget);
    });

    testWidgets('Renders cleanly in Dark Paper theme', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          theme: AppTheme.dark(),
          child: const QuietAssetImageView(
            assetId: smallAssetId,
            altText: 'Dark Paper Image',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Renders base64 data: URI image cleanly', (tester) async {
      final base64String = 'data:image/png;base64,${base64Encode(testSmallImageBytes)}';
      await tester.pumpWidget(
        buildTestWidget(
          child: QuietAssetImageView(
            url: base64String,
            altText: 'Base64 image',
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      final imageFinder = find.byType(Image);
      final imageSize = tester.getSize(imageFinder);
      expect(imageSize.width, 100.0);
      expect(imageSize.height, 100.0);
    });
  });
}
