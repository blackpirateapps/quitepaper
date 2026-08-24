import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_models.dart';
import 'package:quitepaper/core/ocr/document_processing_service.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/ocr/presentation/ocr_text_viewer_screen.dart';

class MockTestKeyManager implements KeyManager {
  MockTestKeyManager({required this.masterKey, this.isUnlocked = true});
  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  Uint8List getMasterKey() => masterKey;

  @override
  void lock() => isUnlocked = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrTextViewerScreen Tests', () {
    late AppDatabase database;
    late MockTestKeyManager keyManager;
    late DocumentProcessingService processingService;
    late CryptoService cryptoService;

    const testDocId = 'test-ocr-doc-123';

    setUp(() async {
      database = AppDatabase.memory();
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockTestKeyManager(masterKey: masterKey, isUnlocked: true);

      processingService = DocumentProcessingService(
        database: database,
        keyManager: keyManager,
        ocrCrypto: OcrCrypto(cryptoService: cryptoService),
      );

      await database.saveDocument(
        id: testDocId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Invoice Document',
        source: DocumentSource.scanner.identifier,
        ocrState: OcrProcessingState.available.identifier,
      );

      // Save two mock encrypted pages
      final ocrCrypto = OcrCrypto(cryptoService: cryptoService);

      final page1Doc = OcrDocument(
        documentId: testDocId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'ACME Corporation\nInvoice #4829\nTotal: \$1500',
            width: 1000,
            height: 1414,
            source: OcrSource.onDeviceOcr,
          ),
        ],
      );

      final page2Doc = OcrDocument(
        documentId: testDocId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 2,
            plainText: 'Terms and Conditions\nDue upon receipt',
            width: 1000,
            height: 1414,
            source: OcrSource.onDeviceOcr,
          ),
        ],
      );

      final enc1 = await ocrCrypto.encryptOcrDocument(
        ocrDocument: page1Doc,
        masterKeyBytes: masterKey,
      );
      final enc2 = await ocrCrypto.encryptOcrDocument(
        ocrDocument: page2Doc,
        masterKeyBytes: masterKey,
      );

      await database.saveDocumentOcrPage(
        documentId: testDocId,
        pageNumber: 1,
        encryptedPayload: base64Encode(enc1),
        ocrSchemaVersion: 1,
        ocrEngine: 'test_engine',
        ocrEngineVersion: '1.0.0',
        language: 'en',
        processedAt: DateTime.now(),
      );

      await database.saveDocumentOcrPage(
        documentId: testDocId,
        pageNumber: 2,
        encryptedPayload: base64Encode(enc2),
        ocrSchemaVersion: 1,
        ocrEngine: 'test_engine',
        ocrEngineVersion: '1.0.0',
        language: 'en',
        processedAt: DateTime.now(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('Renders page-by-page OCR text with distinct page headers and selectable text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OcrTextViewerScreen(
              documentId: testDocId,
              title: 'Invoice Document',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Invoice Document'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.textContaining('ACME Corporation'), findsOneWidget);
      expect(find.textContaining('Invoice #4829'), findsOneWidget);
      expect(find.textContaining('Terms and Conditions'), findsOneWidget);
    });

    testWidgets('Copy all action copies formatted document text to clipboard', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OcrTextViewerScreen(
              documentId: testDocId,
              title: 'Invoice Document',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Copy All icon in app bar
      await tester.tap(find.byTooltip('Copy all OCR text'));
      await tester.pumpAndSettle();

      expect(find.text('OCR text copied to clipboard'), findsOneWidget);
      expect(copiedClipboardText, contains('Page 1'));
      expect(copiedClipboardText, contains('ACME Corporation'));
      expect(copiedClipboardText, contains('Page 2'));
      expect(copiedClipboardText, contains('Terms and Conditions'));
    });

    testWidgets('Renders empty/unavailable state gracefully when document has no OCR data', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OcrTextViewerScreen(
              documentId: 'non-existent-doc-id',
              title: 'Missing Document',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('OCR Text Unavailable'), findsOneWidget);
      expect(find.textContaining('No OCR text available'), findsOneWidget);
    });

    testWidgets('Displays Jump to Page option in menu for multi-page documents and navigates smoothly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OcrTextViewerScreen(
              documentId: testDocId,
              title: 'Invoice Document',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Jump to Page'), findsOneWidget);

      // Tap Jump to Page
      await tester.tap(find.text('Jump to Page'));
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Enter page number (1 – 2):'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Jump'), findsOneWidget);

      // Enter target page 2
      await tester.enterText(find.byType(TextField), '2');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Jump'));
      await tester.pumpAndSettle();

      expect(find.text('Page 2'), findsOneWidget);
    });
  });
}
