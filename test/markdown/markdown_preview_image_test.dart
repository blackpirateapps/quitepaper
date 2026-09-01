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
import 'package:quitepaper/core/markdown/markdown_preview.dart';
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
      }
    }
    return ResourceResolution.missing(uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuietMarkdownPreview Image Integration Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late Uint8List testImageBytes1;
    late Uint8List testImageBytes2;
    const assetId1 = '550e8400-e29b-41d4-a716-446655440001';
    const assetId2 = '550e8400-e29b-41d4-a716-446655440002';

    setUp(() {
      database = AppDatabase.memory();
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

      final img1 = img.Image(width: 300, height: 150);
      img.fill(img1, color: img.ColorRgb8(120, 160, 200));
      testImageBytes1 = Uint8List.fromList(img.encodePng(img1));

      final img2 = img.Image(width: 250, height: 250);
      img.fill(img2, color: img.ColorRgb8(200, 120, 120));
      testImageBytes2 = Uint8List.fromList(img.encodePng(img2));
    });

    tearDown(() async {
      await database.close();
    });

    Widget buildTestWidget({required String markdownData}) {
      final dataMap = {
        assetId1: testImageBytes1,
        assetId2: testImageBytes2,
      };

      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          keyManagerProvider.overrideWithValue(keyManager),
          attachmentServiceProvider.overrideWithValue(MockAttachmentService(mockDataMap: dataMap)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1200,
              child: QuietMarkdownPreview(
                markdownData: markdownData,
                selectable: false,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders image and caption in markdown preview', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const markdown = '''
# Project Update

Here is the system overview:

![System Architecture](qp://asset/550e8400-e29b-41d4-a716-446655440001 "System architecture diagram during phase 2")

Next steps are outlined below.
''';

      await tester.pumpWidget(buildTestWidget(markdownData: markdown));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Project Update'), findsOneWidget);
      expect(find.text('Here is the system overview:'), findsOneWidget);
      expect(find.byType(QuietAssetImageView), findsOneWidget);
      expect(find.text('System architecture diagram during phase 2'), findsOneWidget);
      expect(find.text('Next steps are outlined below.'), findsOneWidget);
    });

    testWidgets('Multiple images in document order with gallery navigation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const markdown = '''
# Multi-image Report

First observation:

![First Diagram](qp://asset/550e8400-e29b-41d4-a716-446655440001)

Second observation:

![Second Chart](qp://asset/550e8400-e29b-41d4-a716-446655440002)
''';

      await tester.pumpWidget(buildTestWidget(markdownData: markdown));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      final imageViews = find.byType(QuietAssetImageView);
      expect(imageViews, findsNWidgets(2));

      // Tap the second image
      final secondImage = find.descendant(
        of: imageViews.at(1),
        matching: find.byType(Image),
      );
      await tester.tap(secondImage, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Fullscreen viewer opens at 2 / 2
      expect(find.byType(ImageViewerModal), findsOneWidget);
      expect(find.text('Second Chart'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);

      // Navigate to previous image
      final prevButton = find.byTooltip('Previous Image');
      expect(prevButton, findsOneWidget);
      await tester.tap(prevButton);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('First Diagram'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // Close viewer and verify return to preview
      final closeButton = find.byTooltip('Close');
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerModal), findsNothing);
      expect(find.text('Multi-image Report'), findsOneWidget);
    });

    testWidgets('Scrolls smoothly from bottom with multiple images to top without getting stuck', (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      final dataMap = {
        assetId1: testImageBytes1,
        assetId2: testImageBytes2,
      };

      final paragraphs = List.generate(
        15,
        (i) => 'Paragraph $i contains extensive analytical details describing the system behavior.',
      ).join('\n\n');

      final markdown = '''
# Long Document With Bottom Images

$paragraphs

Here are the visual assets at the bottom of the article:

![First Diagram](qp://asset/$assetId1 "First diagram caption")

![Second Chart](qp://asset/$assetId2 "Second chart caption")

Concluding thoughts and final remarks.
''';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            keyManagerProvider.overrideWithValue(keyManager),
            attachmentServiceProvider.overrideWithValue(MockAttachmentService(mockDataMap: dataMap)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 700,
                child: QuietMarkdownPreview(
                  markdownData: markdown,
                  scrollController: scrollController,
                  selectable: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(scrollController.hasClients, isTrue);
      final maxScroll = scrollController.position.maxScrollExtent;
      expect(maxScroll, greaterThan(200.0));

      while (scrollController.offset < scrollController.position.maxScrollExtent) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();
      }

      final bottomOffset = scrollController.offset;
      expect(bottomOffset, greaterThan(200.0));

      // Verify images at bottom are rendered
      expect(find.byType(QuietAssetImageView), findsWidgets);

      // Drag downwards directly over the images to scroll up towards the top
      await tester.drag(find.byType(QuietAssetImageView).last, const Offset(0.0, 300.0));
      await tester.pumpAndSettle();

      // Scroll offset should have decreased (scrolled towards the top)
      expect(scrollController.offset, lessThan(bottomOffset));
    });
  });
}
