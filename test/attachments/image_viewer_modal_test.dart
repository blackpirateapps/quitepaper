import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/presentation/image_viewer_modal.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageViewerModal Widget Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late OcrCrypto ocrCrypto;
    late Uint8List testImageBytes;
    const attachmentId = 'att-widget-test-1';

    setUp(() async {
      database = AppDatabase.memory();
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);
      ocrCrypto = OcrCrypto(cryptoService: cryptoService);

      final testImage = img.Image(width: 200, height: 200);
      img.fill(testImage, color: img.ColorRgb8(200, 200, 200));
      testImageBytes = Uint8List.fromList(img.encodePng(testImage));

      final now = DateTime.now();
      await database.saveAttachment(
        id: attachmentId,
        createdAt: now,
        updatedAt: now,
        ocrState: 'available',
      );

      final ocrDoc = OcrDocument(
        documentId: attachmentId,
        processedAt: now,
        pages: [
          const OcrPage(
            pageNumber: 1,
            plainText: 'Meeting Notes 2026',
            width: 200,
            height: 200,
            blocks: [
              OcrBlock(
                text: 'Meeting Notes 2026',
                bounds: NormalizedRect.full,
                lines: [
                  OcrLine(
                    text: 'Meeting Notes 2026',
                    bounds: NormalizedRect.full,
                    words: [
                      OcrWord(
                        text: 'Meeting',
                        bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
                      ),
                      OcrWord(
                        text: 'Notes',
                        bounds: NormalizedRect(x: 0.45, y: 0.1, width: 0.25, height: 0.1),
                      ),
                      OcrWord(
                        text: '2026',
                        bounds: NormalizedRect(x: 0.75, y: 0.1, width: 0.2, height: 0.1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final encryptedBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: ocrDoc,
        masterKeyBytes: masterKey,
      );

      await database.saveAttachmentOcrPage(
        attachmentId: attachmentId,
        pageNumber: 1,
        encryptedPayload: base64Encode(encryptedBytes),
        processedAt: now,
      );
    });

    tearDown(() async {
      await database.close();
    });

    Widget buildTestWidget({void Function(String text)? onInsertText}) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          keyManagerProvider.overrideWithValue(keyManager),
          ocrCryptoProvider.overrideWithValue(ocrCrypto),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ImageViewerModal(
            assetId: attachmentId,
            altText: 'Whiteboard Capture',
            initialImageBytes: testImageBytes,
            onInsertText: onInsertText,
          ),
        ),
      );
    }

    testWidgets('Renders image, alt text title, InteractiveViewer, and status badge', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Whiteboard Capture'), findsOneWidget);
      expect(find.text('Searchable (OCR)'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Copy All Text'), findsOneWidget);
    });

    testWidgets('Tapping Copy All Text copies text to clipboard', (tester) async {
      String? copiedClipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedClipboardText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy All Text'));
      await tester.pumpAndSettle();

      expect(copiedClipboardText, 'Meeting Notes 2026');
    });

    testWidgets('Insert into Note triggers onInsertText callback', (tester) async {
      String? insertedText;
      await tester.pumpWidget(buildTestWidget(onInsertText: (t) => insertedText = t));
      await tester.pumpAndSettle();

      expect(find.text('Insert into Note'), findsOneWidget);
      await tester.tap(find.text('Insert into Note'));
      await tester.pumpAndSettle();

      expect(insertedText, 'Meeting Notes 2026');
    });

    testWidgets('Toggle Live Text hides/shows overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final liveTextButton = find.byTooltip('Hide Live Text');
      expect(liveTextButton, findsOneWidget);

      await tester.tap(liveTextButton);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Show Live Text'), findsOneWidget);
    });
  });
}
