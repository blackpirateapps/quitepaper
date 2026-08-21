import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

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

  group('Attachment OCR Search Tests', () {
    late AppDatabase database;
    late MockKeyManager keyManager;
    late OcrCrypto ocrCrypto;
    late DriftNotesRepository notesRepository;

    setUp(() async {
      database = AppDatabase.memory();
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);
      ocrCrypto = OcrCrypto(cryptoService: cryptoService);
      notesRepository = DriftNotesRepository(database, keyManager, ocrCrypto);
    });

    tearDown(() async {
      await database.close();
    });

    test('Searching query finds note whose attached image contains the matching text', () async {
      final now = DateTime.now();
      const noteId = 'note-with-image-1';
      const attachmentId = 'att-receipt-1';

      // 1. Create note
      await database.saveNote(
        id: noteId,
        title: 'Expenses July',
        content: 'Check out the attached receipt:\n![Receipt](qp://asset/$attachmentId)',
        tags: ['finance'],
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      // 2. Create attachment linked to note
      await database.saveAttachment(
        id: attachmentId,
        noteId: noteId,
        createdAt: now,
        updatedAt: now,
        ocrState: 'available',
      );

      // 3. Encrypt and save OCR payload containing "Starbucks Coffee $5.75"
      final ocrDoc = OcrDocument(
        documentId: attachmentId,
        processedAt: now,
        pages: [
          const OcrPage(
            pageNumber: 1,
            plainText: 'Starbucks Coffee\nGrande Latte \$5.75\nThank you for visiting!',
            width: 800,
            height: 1200,
          ),
        ],
      );

      final encryptedBytes = await ocrCrypto.encryptOcrDocument(
        ocrDocument: ocrDoc,
        masterKeyBytes: keyManager.getMasterKey(),
      );

      await database.saveAttachmentOcrPage(
        attachmentId: attachmentId,
        pageNumber: 1,
        encryptedPayload: base64Encode(encryptedBytes),
        processedAt: now,
      );

      // 4. Search for "Starbucks" (word not in note title or content)
      final notesStream = notesRepository.watchNotes(searchQuery: 'Starbucks');
      final matchingNotes = await notesStream.first;

      expect(matchingNotes, hasLength(1));
      expect(matchingNotes.first.id, noteId);
      expect(matchingNotes.first.title, 'Expenses July');

      // 5. Search for "Latte"
      final latteNotes = await notesRepository.watchNotes(searchQuery: 'latte').first;
      expect(latteNotes, hasLength(1));
      expect(latteNotes.first.id, noteId);

      // 6. Search for non-existent word
      final emptyNotes = await notesRepository.watchNotes(searchQuery: 'NonExistentProduct').first;
      expect(emptyNotes, isEmpty);
    });
  });
}
