import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/documents/presentation/quiet_document_card.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FormattingToolbar Scanner Button Placement & Actions', () {
    testWidgets('Renders scan button immediately adjacent to image button and triggers callback', (tester) async {
      final controller = TextEditingController();
      var scanTriggered = false;
      var imageTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FormattingToolbar(
              controller: controller,
              onTagPressed: () {},
              onImagePressed: () => imageTriggered = true,
              onScanPressed: () => scanTriggered = true,
            ),
          ),
        ),
      );

      final imageFinder = find.byIcon(Icons.image_outlined);
      final scanFinder = find.byIcon(Icons.document_scanner_outlined);

      expect(imageFinder, findsOneWidget);
      expect(scanFinder, findsOneWidget);

      await tester.tap(scanFinder);
      await tester.pump();

      expect(scanTriggered, isTrue);
      expect(imageTriggered, isFalse);
    });
  });

  group('DocumentViewerScreen & QuietDocumentCard Widget Tests', () {
    late AppDatabase database;
    late Directory tempDir;
    late DocumentLocalStorage storage;
    late MockKeyManager keyManager;
    late DocumentService documentService;
    late CryptoService cryptoService;

    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 sample PDF payload'));

    setUp(() async {
      database = AppDatabase.memory();
      tempDir = await Directory.systemTemp.createTemp('qp_test_viewer_');
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

    testWidgets('Renders DocumentViewerScreen with export actions and header info', (tester) async {
      late final ({DocumentEntity document, String markdownSnippet}) createResult;
      late final ResourceResolution<ResolvedDocumentInfo> resolution;

      await tester.runAsync(() async {
        createResult = await documentService.createDocumentFromPdfBytes(
          pdfBytes: samplePdfBytes,
          pageCount: 3,
          title: 'Monthly Statement',
        );
        resolution = await documentService.resolveDocument(createResult.document.id);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(documentService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: createResult.document.id,
              title: 'Monthly Statement',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Monthly Statement'), findsWidgets);
      expect(find.textContaining('3 pages'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    });

    testWidgets('QuietMarkdownPreview renders QuietDocumentCard for [Title](qp://document/UUID)', (tester) async {
      late final ({DocumentEntity document, String markdownSnippet}) createResult;

      await tester.runAsync(() async {
        createResult = await documentService.createDocumentFromPdfBytes(
          pdfBytes: samplePdfBytes,
          pageCount: 2,
          title: 'Rental Agreement',
        );
      });

      final markdownText = '# My Note\n\n${createResult.markdownSnippet}\n\nSome trailing text.';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(documentService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: QuietMarkdownPreview(
                markdownData: markdownText,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(QuietDocumentCard), findsOneWidget);
      expect(find.text('Rental Agreement'), findsWidgets);
      expect(find.textContaining('2 pages'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });
  });
}
