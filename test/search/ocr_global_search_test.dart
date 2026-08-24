import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/attachments/presentation/image_viewer_modal.dart';
import 'package:quitepaper/core/documents/presentation/document_viewer_screen.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/ocr/ocr_search_service.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:quitepaper/features/search/application/search_provider.dart';
import 'package:quitepaper/features/search/presentation/search_screen.dart';
import 'package:quitepaper/features/search/presentation/widgets/document_search_tile.dart';
import 'package:quitepaper/features/search/presentation/widgets/search_filter_bar.dart';

class _FakeKeyManager implements KeyManager {
  _FakeKeyManager(this._masterKey);

  final Uint8List _masterKey;
  bool _unlocked = true;

  @override
  bool get isUnlocked => _unlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List? get cachedMasterKey => _unlocked ? _masterKey : null;

  @override
  Uint8List getMasterKey() {
    if (!_unlocked) throw StateError('Locked');
    return _masterKey;
  }

  @override
  void lock() => _unlocked = false;

  void unlock() => _unlocked = true;

  @override
  Future<void> clearLocalKeys() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<WrappedMasterKeyData?> getStoredWrappedKeyData() async => null;

  @override
  Future<void> storeWrappedKeyData(WrappedMasterKeyData data) async {}

  @override
  Future<WrappedMasterKeyData> setupNewKeys({
    required String password,
    String? recoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unlockWithPassword({
    required String password,
    WrappedMasterKeyData? remoteWrappedKey,
  }) async {}

  @override
  Future<void> unlockWithRecoveryKey({
    required String recoveryKey,
    WrappedMasterKeyData? remoteWrappedKey,
  }) async {}

  @override
  Future<WrappedMasterKeyData> changePassword({
    required String newPassword,
    String? newRecoveryKey,
    KdfParameters kdfParameters = const KdfParameters(),
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  late AppDatabase db;
  late _FakeKeyManager keyManager;
  late OcrCrypto ocrCrypto;
  late OcrSearchService searchService;
  late Uint8List masterKey;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    masterKey = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
    keyManager = _FakeKeyManager(masterKey);
    ocrCrypto = OcrCrypto(cryptoService: DefaultCryptoService());
    searchService = OcrSearchService(
      database: db,
      keyManager: keyManager,
      ocrCrypto: ocrCrypto,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> createDocumentWithOcr({
    required String documentId,
    required String title,
    String? noteId,
    required List<String> pageTexts,
  }) async {
    final now = DateTime.now();
    await db.saveDocument(
      id: documentId,
      title: title,
      noteId: noteId,
      createdAt: now,
      updatedAt: now,
      byteSize: 1024,
      pageCount: pageTexts.length,
      sha256: 'fake_sha256',
      ocrState: 'available',
      ocrLanguage: 'en',
    );

    for (var i = 0; i < pageTexts.length; i++) {
      final pageNum = i + 1;
      final ocrDoc = OcrDocument(
        documentId: documentId,
        language: OcrLanguage.english,
        engine: 'test_engine',
        engineVersion: '1.0.0',
        schemaVersion: 1,
        processedAt: now,
        pages: [
          OcrPage(
            pageNumber: pageNum,
            plainText: pageTexts[i],
            width: 800,
            height: 1100,
            blocks: [
              OcrBlock(
                text: pageTexts[i],
                bounds: NormalizedRect.full,
                lines: [],
              ),
            ],
          ),
        ],
      );

      final encrypted = await ocrCrypto.encryptOcrDocument(
        ocrDocument: ocrDoc,
        masterKeyBytes: masterKey,
      );

      await db.saveDocumentOcrPage(
        documentId: documentId,
        pageNumber: pageNum,
        encryptedPayload: base64Encode(encrypted),
        language: 'en',
        processedAt: now,
      );
    }
  }

  Future<void> createAttachmentWithOcr({
    required String attachmentId,
    String? noteId,
    required String text,
  }) async {
    final now = DateTime.now();
    await db.saveAttachment(
      id: attachmentId,
      noteId: noteId,
      createdAt: now,
      updatedAt: now,
      ocrState: 'available',
      ocrLanguage: 'en',
    );

    final ocrDoc = OcrDocument(
      documentId: attachmentId,
      language: OcrLanguage.english,
      engine: 'test_engine',
      engineVersion: '1.0.0',
      schemaVersion: 1,
      processedAt: now,
      pages: [
        OcrPage(
          pageNumber: 1,
          plainText: text,
          width: 800,
          height: 1200,
          blocks: [
            OcrBlock(
              text: text,
              bounds: NormalizedRect.full,
              lines: [],
            ),
          ],
        ),
      ],
    );

    final encrypted = await ocrCrypto.encryptOcrDocument(
      ocrDocument: ocrDoc,
      masterKeyBytes: masterKey,
    );

    await db.saveAttachmentOcrPage(
      attachmentId: attachmentId,
      pageNumber: 1,
      encryptedPayload: base64Encode(encrypted),
      language: 'en',
      processedAt: now,
    );
  }

  group('OcrSearchService Tests', () {
    test('Searches OCR text in attached and unattached documents with exact match', () async {
      // 1. Attached document
      await db.saveNote(
        id: 'note-101',
        title: 'Q3 Financial Review',
        content: 'Check attached invoice for software licenses.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await createDocumentWithOcr(
        documentId: 'doc-invoice-1',
        title: 'Vendor Invoice 2026',
        noteId: 'note-101',
        pageTexts: [
          'Overview page without keyword.',
          'Acme Corp invoice #9842 total due: \$4,200.00 due by end of month.',
        ],
      );

      // 2. Unattached document
      await createDocumentWithOcr(
        documentId: 'doc-unattached-1',
        title: 'Electricity Statement',
        noteId: null,
        pageTexts: [
          'Utility invoice bill for account #5512 amount \$140.00.',
        ],
      );

      // Search for "invoice"
      final matches = await searchService.searchDocuments('invoice');
      expect(matches.length, 2);

      // Match 1: Attached document on page 2
      final attachedMatch = matches.firstWhere((m) => m.id == 'doc-invoice-1');
      expect(attachedMatch.matchedPageNumber, 2);
      expect(attachedMatch.parentNoteTitle, 'Q3 Financial Review');
      expect(attachedMatch.parentNoteId, 'note-101');
      expect(attachedMatch.isOcrMatch, isTrue);
      expect(attachedMatch.snippet.toLowerCase(), contains('invoice #9842'));

      // Match 2: Unattached document on page 1
      final unattachedMatch = matches.firstWhere((m) => m.id == 'doc-unattached-1');
      expect(unattachedMatch.matchedPageNumber, 1);
      expect(unattachedMatch.parentNoteTitle, isNull);
      expect(unattachedMatch.parentNoteId, isNull);
      expect(unattachedMatch.isOcrMatch, isTrue);
      expect(unattachedMatch.snippet.toLowerCase(), contains('utility invoice bill'));
    });

    test('Fuzzy search finds OCR text with typos (e.g. "invioce")', () async {
      await createDocumentWithOcr(
        documentId: 'doc-typo-1',
        title: 'Hardware Order Receipt',
        noteId: null,
        pageTexts: [
          'Dell server invoice #1029 total \$8,900 shipped via FedEx.',
        ],
      );

      // Search with transposition typo "invioce"
      final matches = await searchService.searchDocuments('invioce');
      expect(matches.length, 1);
      expect(matches.first.id, 'doc-typo-1');
      expect(matches.first.isFuzzy, isTrue);
      expect(matches.first.snippet.toLowerCase(), contains('dell server invoice'));
    });

    test('Searches document title when OCR does not match', () async {
      await createDocumentWithOcr(
        documentId: 'doc-contract-1',
        title: 'Employment Agreement 2026',
        noteId: null,
        pageTexts: [
          'Confidential terms and working hours.',
        ],
      );

      final matches = await searchService.searchDocuments('Agreement');
      expect(matches.length, 1);
      expect(matches.first.id, 'doc-contract-1');
      expect(matches.first.isOcrMatch, isFalse);
      expect(matches.first.matchedPageNumber, 1);
    });

    test('In-memory cache accelerates subsequent search queries', () async {
      await createDocumentWithOcr(
        documentId: 'doc-speed-test',
        title: 'Cached Document',
        noteId: null,
        pageTexts: [
          'Deep neural networks and artificial intelligence systems.',
        ],
      );

      // First pass populates cache
      final initialMatches = await searchService.searchDocuments('intelligence');
      expect(initialMatches.length, 1);

      // Second pass searches in-memory cache directly
      final secondMatches = await searchService.searchDocuments('neural');
      expect(secondMatches.length, 1);
      expect(secondMatches.first.snippet.toLowerCase(), contains('deep neural networks'));
    });

    test('Searches OCR text in image attachments with exact and fuzzy matching', () async {
      await db.saveNote(
        id: 'note-att-1',
        title: 'Monthly Expenses',
        content: 'Attached receipt for coffee.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await createAttachmentWithOcr(
        attachmentId: 'att-starbucks-1',
        noteId: 'note-att-1',
        text: 'Starbucks Coffee\nCaramel Macchiato \$6.25\nStore #4829',
      );

      final matches = await searchService.searchDocuments('Macchiato');
      expect(matches.length, 1);
      expect(matches.first.id, 'att-starbucks-1');
      expect(matches.first.isAttachment, isTrue);
      expect(matches.first.parentNoteTitle, 'Monthly Expenses');
      expect(matches.first.parentNoteId, 'note-att-1');
      expect(matches.first.snippet.toLowerCase(), contains('caramel macchiato'));
    });
  });

  group('Global Search Provider & Screen UI Integration', () {
    testWidgets('Renders SearchFilterBar, fuzzy highlights, DocumentSearchTile, and surfaces parent note in Notes', (tester) async {
      // Setup Note and Document in DB
      await db.saveNote(
        id: 'note-ui-1',
        title: 'Project Roadmap',
        content: 'Discussion about upcoming releases.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        tags: ['planning'],
      );

      await createDocumentWithOcr(
        documentId: 'doc-ui-1',
        title: 'System Blueprint',
        noteId: 'note-ui-1',
        pageTexts: [
          'Page 1: System overview diagram.',
          'Page 2: Database architecture blueprint with SQLite schema.',
        ],
      );

      final notesRepo = DriftNotesRepository(db, keyManager, ocrCrypto);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(notesRepo),
          keyManagerProvider.overrideWithValue(keyManager),
          ocrCryptoProvider.overrideWithValue(ocrCrypto),
          ocrSearchServiceProvider.overrideWithValue(searchService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchScreen(initialQuery: 'architecture'),
          ),
        ),
      );

      // Post-frame callback triggers searchQueryProvider update
      await tester.pump();
      // Allow debouncer and background search isolate to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // Verify SearchFilterBar exists
      expect(find.byType(SearchFilterBar), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Documents & OCR'), findsOneWidget);

      // Dual surfacing in "All" view: Both NoteListTile and DocumentSearchTile appear
      expect(find.byType(DocumentSearchTile), findsOneWidget);
      expect(find.text('System Blueprint'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('OCR Match'), findsOneWidget);
      expect(find.text('In: Project Roadmap'), findsOneWidget);

      expect(find.byType(NoteListTile), findsOneWidget);
      expect(find.text('Project Roadmap'), findsOneWidget);

      // Tap filter chip "Notes" -> NoteListTile remains visible
      await tester.tap(find.text('Notes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(searchFilterProvider), SearchFilter.notes);
      expect(find.byType(NoteListTile), findsOneWidget);
      expect(find.byType(DocumentSearchTile), findsNothing);

      // Tap filter chip "Documents & OCR" -> DocumentSearchTile is visible
      await tester.tap(find.text('Documents & OCR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(searchFilterProvider), SearchFilter.documents);
      expect(find.byType(DocumentSearchTile), findsOneWidget);
      expect(find.byType(NoteListTile), findsNothing);

      // Tap the document tile to verify it triggers DocumentViewerScreen
      await tester.tap(find.byType(DocumentSearchTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DocumentViewerScreen), findsOneWidget);
    });

    testWidgets('Surfaces Image Attachment OCR match and opens ImageViewerModal on tap', (tester) async {
      await db.saveNote(
        id: 'note-img-test',
        title: 'Hardware Receipts',
        content: 'Receipts for office setup.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await createAttachmentWithOcr(
        attachmentId: 'att-logitech-1',
        noteId: 'note-img-test',
        text: 'Best Buy\nLogitech MX Master 3S Wireless Mouse\nPrice: \$99.99',
      );

      final notesRepo = DriftNotesRepository(db, keyManager, ocrCrypto);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(notesRepo),
          keyManagerProvider.overrideWithValue(keyManager),
          ocrCryptoProvider.overrideWithValue(ocrCrypto),
          ocrSearchServiceProvider.overrideWithValue(searchService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchScreen(initialQuery: 'Logitech'),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      // Verify DocumentSearchTile shows image OCR match
      expect(find.byType(DocumentSearchTile), findsOneWidget);
      expect(find.text('Image Attachment'), findsOneWidget);
      expect(find.text('Image OCR Match'), findsOneWidget);
      expect(find.text('In: Hardware Receipts'), findsOneWidget);

      // Verify parent note appears under NoteListTile
      expect(find.byType(NoteListTile), findsOneWidget);
      expect(find.text('Hardware Receipts'), findsOneWidget);

      // Tap Image tile -> triggers ImageViewerModal
      await tester.tap(find.byType(DocumentSearchTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ImageViewerModal), findsOneWidget);
    });
  });
}
