import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/ocr/document_processing_service.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/ocr/presentation/ocr_text_viewer_screen.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';

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

  group('DocumentViewerScreen OCR Actions & Menu Tests', () {
    late AppDatabase database;
    late MockTestKeyManager keyManager;
    late DocumentProcessingService processingService;
    late CryptoService cryptoService;

    const testDocId = 'doc-viewer-test-uuid';
    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 mock pdf'));

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

      final ocrCrypto = OcrCrypto(cryptoService: cryptoService);
      final pageDoc = OcrDocument(
        documentId: testDocId,
        processedAt: DateTime.now(),
        pages: const [
          OcrPage(
            pageNumber: 1,
            plainText: 'Sample OCR Content Inside Document',
            width: 1000,
            height: 1414,
            source: OcrSource.onDeviceOcr,
          ),
        ],
      );

      final enc = await ocrCrypto.encryptOcrDocument(
        ocrDocument: pageDoc,
        masterKeyBytes: masterKey,
      );

      await database.saveDocumentOcrPage(
        documentId: testDocId,
        pageNumber: 1,
        encryptedPayload: base64Encode(enc),
        ocrSchemaVersion: 1,
        ocrEngine: 'test',
        ocrEngineVersion: '1.0.0',
        language: 'en',
        processedAt: DateTime.now(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('Shows Searchable badge and View OCR Text action when OCR is available', (tester) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          pdfBytes: samplePdfBytes,
          pageCount: 1,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          title: 'Scanned Receipt',
          ocrState: 'available',
          ocrLanguage: 'en',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Scanned Receipt',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Scanned Receipt'), findsOneWidget);
      expect(find.text('Searchable (OCR)'), findsOneWidget);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rename Document'), findsOneWidget);
      expect(find.text('View OCR Text'), findsOneWidget);
      expect(find.text('Copy OCR Text'), findsOneWidget);
      expect(find.text('OCR Language'), findsOneWidget);
    });

    testWidgets('Tapping View OCR Text action navigates to OcrTextViewerScreen', (tester) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          pdfBytes: samplePdfBytes,
          pageCount: 1,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          title: 'Scanned Receipt',
          ocrState: 'available',
          ocrLanguage: 'en',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Scanned Receipt',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the View OCR Text icon button in AppBar
      await tester.tap(find.byIcon(Icons.article_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(OcrTextViewerScreen), findsOneWidget);
      expect(find.textContaining('Sample OCR Content Inside Document'), findsOneWidget);
    });

    testWidgets('Shows Retry OCR in menu when OCR state is failed', (tester) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          pdfBytes: samplePdfBytes,
          pageCount: 1,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          title: 'Failed Scan Document',
          ocrState: 'failed',
          ocrLanguage: 'en',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentProcessingServiceProvider.overrideWithValue(processingService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Failed Scan Document',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('OCR unavailable'), findsOneWidget);

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Run / Regenerate OCR'), findsOneWidget);
    });
  });
}
