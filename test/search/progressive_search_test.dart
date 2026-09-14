import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/ocr_provider.dart';
import 'package:quitepaper/core/ocr/ocr_search_service.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/search/application/search_provider.dart';

class _FakeKeyManager implements KeyManager {
  _FakeKeyManager(this._masterKey);

  final Uint8List _masterKey;

  @override
  bool get isUnlocked => true;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List? get cachedMasterKey => _masterKey;

  @override
  Uint8List getMasterKey() => _masterKey;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Progressive 3-Tier Search Pipeline Tests', () {
    late AppDatabase db;
    late _FakeKeyManager keyManager;
    late OcrCrypto ocrCrypto;
    late OcrSearchService searchService;
    late DriftNotesRepository notesRepo;
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
      notesRepo = DriftNotesRepository(db, keyManager, ocrCrypto);
    });

    tearDown(() async {
      await db.close();
    });

    test('Emits Phase 1 (Titles & Tags) instantly, then Phase 2 (Body), then Phase 3 (OCR)', () async {
      // Note 1: matches in TITLE
      await db.saveNote(
        id: 'note-title-only',
        title: 'Project Helium Alpha',
        content: 'Unrelated general notes about everyday schedule.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Note 2: matches in BODY only
      await db.saveNote(
        id: 'note-body-only',
        title: 'Meeting Notes',
        content: 'Discussing the Helium deployment timetable for next quarter.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(notesRepo),
          keyManagerProvider.overrideWithValue(keyManager),
          ocrCryptoProvider.overrideWithValue(ocrCrypto),
          ocrSearchServiceProvider.overrideWithValue(searchService),
        ],
      );

      // Set query to 'Helium'
      container.read(searchQueryProvider.notifier).state = 'Helium';

      final emittedPhases = <SearchPhase>[];
      final emittedResults = <GlobalSearchResults>[];
      final completer = Completer<void>();

      final subscription = container.listen(
        globalSearchResultsProvider,
        (prev, next) {
          final val = next.valueOrNull;
          if (val != null) {
            emittedPhases.add(val.searchPhase);
            emittedResults.add(val);
            if (val.searchPhase == SearchPhase.complete && !completer.isCompleted) {
              completer.complete();
            }
          }
        },
      );

      // Await until Phase 3 complete
      await completer.future;
      subscription.close();

      // Verify all 3 tiers were yielded in order
      expect(emittedPhases, containsAllInOrder([
        SearchPhase.titlesAndTags,
        SearchPhase.bodyContent,
        SearchPhase.complete,
      ]));

      // Phase 1 verification: Note 1 (title match) must be present immediately
      final phase1Result = emittedResults.firstWhere((r) => r.searchPhase == SearchPhase.titlesAndTags);
      expect(phase1Result.noteMatches.any((m) => m.note.id == 'note-title-only'), isTrue);

      // Phase 2 verification: Note 2 (body match) is now included
      final phase2Result = emittedResults.firstWhere((r) => r.searchPhase == SearchPhase.bodyContent);
      expect(phase2Result.noteMatches.any((m) => m.note.id == 'note-body-only'), isTrue);
      expect(phase2Result.noteMatches.any((m) => m.note.id == 'note-title-only'), isTrue);
    });

    test('Streams OCR document match into Phase 3 while Phase 1 and 2 complete cleanly', () async {
      // Note with OCR attachment only
      await db.saveNote(
        id: 'note-ocr-parent',
        title: 'Tax Receipts 2026',
        content: 'Attached scanned receipts.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Create OCR document with unique keyword 'Patagonia'
      final now = DateTime.now();
      final ocrDoc = OcrDocument(
        documentId: 'doc-ocr-1',
        language: OcrLanguage.english,
        engine: 'test_engine',
        engineVersion: '1.0.0',
        schemaVersion: 1,
        processedAt: now,
        pages: [
          const OcrPage(
            pageNumber: 1,
            plainText: 'Patagonia Outdoor Gear Store\nFleece Jacket \$149.00',
            width: 800,
            height: 1200,
            blocks: [],
          ),
        ],
      );

      final envelopeBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: ocrDoc,
        masterKeyBytes: masterKey,
      );

      await db.saveDocument(
        id: 'doc-ocr-1',
        title: 'Gear Receipt',
        noteId: 'note-ocr-parent',
        createdAt: now,
        updatedAt: now,
        byteSize: 1024,
        pageCount: 1,
        sha256: 'sha256-doc-ocr-1',
        ocrState: 'available',
        ocrLanguage: 'en',
      );

      await db.saveDocumentOcrPage(
        documentId: 'doc-ocr-1',
        pageNumber: 1,
        encryptedPayload: base64Encode(envelopeBytes),
        language: 'en',
        processedAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(notesRepo),
          keyManagerProvider.overrideWithValue(keyManager),
          ocrCryptoProvider.overrideWithValue(ocrCrypto),
          ocrSearchServiceProvider.overrideWithValue(searchService),
        ],
      );

      container.read(searchQueryProvider.notifier).state = 'Patagonia';

      final streamResults = <GlobalSearchResults>[];
      final completer = Completer<void>();

      final subscription = container.listen(
        globalSearchResultsProvider,
        (prev, next) {
          final val = next.valueOrNull;
          if (val != null) {
            streamResults.add(val);
            if (val.searchPhase == SearchPhase.complete && !completer.isCompleted) {
              completer.complete();
            }
          }
        },
      );

      // Await until Phase 3 complete
      await completer.future;
      subscription.close();

      // Phase 1 & 2 should have 0 document matches
      final phase1 = streamResults.firstWhere((r) => r.searchPhase == SearchPhase.titlesAndTags);
      expect(phase1.documentMatches, isEmpty);

      // Phase 3 must include the OCR match and attributed parent note
      final phase3 = streamResults.firstWhere((r) => r.searchPhase == SearchPhase.complete);
      expect(phase3.documentMatches.length, equals(1));
      expect(phase3.documentMatches.first.id, equals('doc-ocr-1'));
      expect(phase3.documentMatches.first.parentNoteId, equals('note-ocr-parent'));
      expect(phase3.noteMatches.any((m) => m.note.id == 'note-ocr-parent'), isTrue);
    });
  });
}
