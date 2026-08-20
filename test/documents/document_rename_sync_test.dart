import 'dart:convert';
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
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

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

  group('Document Renaming & Bidirectional Sync Tests', () {
    late AppDatabase database;
    late MockTestKeyManager keyManager;
    late DocumentService documentService;
    late DriftNotesRepository notesRepository;
    late CryptoService cryptoService;

    const testDocId = 'doc-rename-test-uuid-1234';
    final samplePdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 mock pdf payload'));

    setUp(() async {
      database = AppDatabase.memory();
      cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockTestKeyManager(masterKey: masterKey, isUnlocked: true);

      documentService = DocumentService(
        database: database,
        keyManager: keyManager,
        crypto: DocumentCrypto(cryptoService: cryptoService),
      );

      notesRepository = DriftNotesRepository(database);

      await database.saveDocument(
        id: testDocId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Original Document Name',
        source: 'scanner',
        ocrState: 'available',
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('Editing markdown document title inside note automatically updates document title in database on save', () async {
      const noteId = 'test-note-sync-1';
      final note = Note(
        id: noteId,
        title: 'Meeting Notes',
        content: 'Check the agreement here: [Brand New Agreement Title](qp://document/$testDocId) for details.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save note via repository
      await notesRepository.saveNote(note);

      // Verify the document's title in DB was updated to match the edited markdown link label
      final updatedDoc = await database.getDocument(testDocId);
      expect(updatedDoc?.title, equals('Brand New Agreement Title'));
    });

    testWidgets('DocumentViewerScreen displays rename icon and allows renaming document', (tester) async {
      final resolution = ResourceResolution.available(
        QuietPaperUri.document(testDocId),
        ResolvedDocumentInfo(
          documentId: testDocId,
          pdfBytes: samplePdfBytes,
          pageCount: 1,
          byteSize: samplePdfBytes.length,
          sha256: 'mocksha',
          title: 'Original Document Name',
          ocrState: 'available',
          ocrLanguage: 'en',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentServiceProvider.overrideWithValue(documentService),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: DocumentViewerScreen(
              documentId: testDocId,
              title: 'Original Document Name',
              initialResolution: resolution,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Original Document Name'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Tap Rename icon button in AppBar
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify rename dialog opened
      expect(find.text('Rename Document'), findsOneWidget);
      expect(find.text('Enter a new name for this document:'), findsOneWidget);

      // Enter new document name
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Updated Via Viewer');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Rename button in dialog
      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify title updated in AppBar
      expect(find.text('Updated Via Viewer'), findsOneWidget);

      // Verify title updated in DB
      final docInDb = await database.getDocument(testDocId);
      expect(docInDb?.title, equals('Updated Via Viewer'));
    });

    test('Searching notes matches notes containing attached documents by document title', () async {
      const noteAId = 'note-with-insurance-doc';
      const docInsuranceId = 'doc-insurance-999';

      await database.saveDocument(
        id: docInsuranceId,
        noteId: noteAId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Health Insurance Policy 2026',
        source: 'scanner',
        ocrState: 'available',
      );

      final note = Note(
        id: noteAId,
        title: 'General Files',
        content: 'Attached file: [Health Insurance Policy 2026](qp://document/$docInsuranceId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await notesRepository.saveNote(note);

      // Search for "Insurance"
      final searchStream = notesRepository.watchNotes(searchQuery: 'Insurance');
      final matchedNotes = await searchStream.first;

      expect(matchedNotes.length, equals(1));
      expect(matchedNotes.first.id, equals(noteAId));
    });

    test('Searching notes matches notes whose attached document OCR text matches search query', () async {
      const noteReceiptId = 'note-with-grocery-receipt';
      const docReceiptId = 'doc-grocery-receipt-777';
      final ocrCrypto = OcrCrypto(cryptoService: cryptoService);

      // Create repository with KeyManager & OcrCrypto
      final secureNotesRepo = DriftNotesRepository(database, keyManager, ocrCrypto);

      await database.saveDocument(
        id: docReceiptId,
        noteId: noteReceiptId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        title: 'Scanned Document 777', // Title does not contain Avocado
        source: 'scanner',
        ocrState: 'available',
      );

      // Save encrypted OCR page containing the word "Avocado"
      final ocrDoc = OcrDocument(
        documentId: docReceiptId,
        language: OcrLanguage.english,
        engine: 'google_mlkit_ocr',
        engineVersion: '0.17.1',
        schemaVersion: 1,
        processedAt: DateTime.now(),
        pages: [
          const OcrPage(
            pageNumber: 1,
            plainText: 'Receipt #9921\nItem: Avocado Organic \$3.99\nTotal: \$3.99',
            width: 1000,
            height: 1400,
            source: OcrSource.onDeviceOcr,
            blocks: [],
          ),
        ],
      );

      final encryptedOcrBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: ocrDoc,
        masterKeyBytes: keyManager.getMasterKey(),
      );

      await database.saveDocumentOcrPage(
        documentId: docReceiptId,
        pageNumber: 1,
        encryptedPayload: base64Encode(encryptedOcrBytes),
        processedAt: DateTime.now(),
      );

      final note = Note(
        id: noteReceiptId,
        title: 'Weekly Expense', // Title does not contain Avocado
        content: 'See attached receipt: [Scanned Document 777](qp://document/$docReceiptId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await secureNotesRepo.saveNote(note);

      // Search for "Avocado"
      final searchStream = secureNotesRepo.watchNotes(searchQuery: 'Avocado');
      final matchedNotes = await searchStream.first;

      expect(matchedNotes.length, equals(1));
      expect(matchedNotes.first.id, equals(noteReceiptId));
    });
  });
}
