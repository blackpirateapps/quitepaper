import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_service.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/pdf/pdf_page_renderer.dart';

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
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePdfPageRenderer implements PdfPageRenderer {
  int renderCallCount = 0;

  @override
  Future<List<RenderedPage>> renderPages(
    Uint8List pdfBytes, {
    List<int>? pageIndices,
    double dpi = 150.0,
  }) async {
    renderCallCount++;
    final list = <RenderedPage>[];
    for (final idx in (pageIndices ?? [0])) {
      list.add(
        RenderedPage(
          pageNumber: idx + 1,
          imageBytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, idx]),
          width: 100,
          height: 140,
        ),
      );
    }
    return list;
  }

  @override
  Future<RenderedPage?> renderSinglePage(
    Uint8List pdfBytes,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    final pages = await renderPages(
      pdfBytes,
      pageIndices: [pageIndex],
      dpi: dpi,
    );
    return pages.isNotEmpty ? pages.first : null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfThumbnailService Tests', () {
    late Directory tempDir;
    late MockKeyManager keyManager;
    late DocumentCrypto crypto;
    late FakePdfPageRenderer renderer;
    late PdfThumbnailService thumbnailService;

    final dummyPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qp_thumb_test_');
      final cryptoService = DefaultCryptoService();
      final masterKey = cryptoService.generateRandomBytes(32);
      keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);
      crypto = DocumentCrypto(cryptoService: cryptoService);
      renderer = FakePdfPageRenderer();

      thumbnailService = PdfThumbnailService(
        keyManager: keyManager,
        crypto: crypto,
        renderer: renderer,
        customDirectory: tempDir,
      );
    });

    tearDown(() async {
      await thumbnailService.flushPendingWrites();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('3-tier caching: render -> encrypted disk persist -> memory cache -> disk fallback', () async {
      const docId = 'doc-test-123';
      const pageIndex = 0;

      // 1. Initial retrieval: renders via renderer and returns PNG bytes
      final bytes1 = await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
        pdfBytes: dummyPdfBytes,
      );

      expect(bytes1, isNotNull);
      expect(bytes1, equals(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0])));
      expect(renderer.renderCallCount, equals(1));

      // Await background async disk write
      await thumbnailService.flushPendingWrites();

      // Check disk persistence
      final hasDisk = await thumbnailService.hasDiskThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
      );
      expect(hasDisk, isTrue);

      // Verify file on disk is encrypted with QPD1 header (not raw PNG bytes)
      final docDir = await thumbnailService.getThumbnailDirectory(docId);
      final thumbFile = File('${docDir.path}/page_$pageIndex.qpthumb');
      final rawDiskBytes = await thumbFile.readAsBytes();
      expect(rawDiskBytes.sublist(0, 4), equals(DocumentCrypto.magicBytes));

      // 2. In-memory cache hit: returns without disk I/O or renderer call
      final bytes2 = await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
        pdfBytes: dummyPdfBytes,
      );
      expect(bytes2, equals(bytes1));
      expect(renderer.renderCallCount, equals(1)); // Still 1

      // 3. Clear memory cache: should decrypt from disk cache without re-rendering
      thumbnailService.invalidateMemoryCache(docId);
      final bytes3 = await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
        pdfBytes: dummyPdfBytes,
      );
      expect(bytes3, equals(bytes1));
      expect(renderer.renderCallCount, equals(1)); // Still 1! Decrypted from disk
    });

    test('Concurrent requests for the same page are deduplicated', () async {
      const docId = 'doc-dedup-test';
      const pageIndex = 1;

      final results = await Future.wait([
        thumbnailService.getPageThumbnail(
          documentId: docId,
          pageIndex: pageIndex,
          pdfBytes: dummyPdfBytes,
        ),
        thumbnailService.getPageThumbnail(
          documentId: docId,
          pageIndex: pageIndex,
          pdfBytes: dummyPdfBytes,
        ),
        thumbnailService.getPageThumbnail(
          documentId: docId,
          pageIndex: pageIndex,
          pdfBytes: dummyPdfBytes,
        ),
      ]);

      expect(results[0], isNotNull);
      expect(results[1], equals(results[0]));
      expect(results[2], equals(results[0]));
      expect(renderer.renderCallCount, equals(1));
    });

    test('Self-healing: corrupted disk file is detected, deleted, and re-rendered', () async {
      const docId = 'doc-corrupt-test';
      const pageIndex = 0;

      // Render and persist first
      await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
        pdfBytes: dummyPdfBytes,
      );
      await thumbnailService.flushPendingWrites();

      // Overwrite disk file with corrupted bytes
      final docDir = await thumbnailService.getThumbnailDirectory(docId);
      final thumbFile = File('${docDir.path}/page_$pageIndex.qpthumb');
      await thumbFile.writeAsBytes(Uint8List.fromList([0x51, 0x50, 0x44, 0x31, 0xFF, 0xEE])); // Corrupt envelope

      // Invalidate memory cache to force reading disk
      thumbnailService.invalidateMemoryCache(docId);

      // Should heal: attempt decryption, fail gracefully, re-render, and return fresh bytes
      final healedBytes = await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: pageIndex,
        pdfBytes: dummyPdfBytes,
      );

      expect(healedBytes, isNotNull);
      expect(renderer.renderCallCount, equals(2)); // Re-rendered once more
    });

    test('deleteThumbnails removes memory cache and deletes disk files', () async {
      const docId = 'doc-delete-test';
      await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: 0,
        pdfBytes: dummyPdfBytes,
      );
      await thumbnailService.flushPendingWrites();

      expect(await thumbnailService.hasDiskThumbnail(documentId: docId, pageIndex: 0), isTrue);

      await thumbnailService.deleteThumbnails(docId);

      expect(await thumbnailService.hasDiskThumbnail(documentId: docId, pageIndex: 0), isFalse);
      final docDir = await thumbnailService.getThumbnailDirectory(docId, create: false);
      expect(await docDir.exists(), isFalse);
    });

    test('DocumentService.deleteDocument triggers thumbnail cleanup', () async {
      final db = AppDatabase.memory();
      final docStorage = DocumentLocalStorage(
        customDocumentsDirectory: tempDir,
        customTempDirectory: tempDir,
      );

      final documentService = DocumentService(
        database: db,
        keyManager: keyManager,
        crypto: crypto,
        storage: docStorage,
        thumbnailService: thumbnailService,
      );

      const docId = 'doc-cascade-test';
      // Generate thumbnail
      await thumbnailService.getPageThumbnail(
        documentId: docId,
        pageIndex: 0,
        pdfBytes: dummyPdfBytes,
      );
      await thumbnailService.flushPendingWrites();
      expect(await thumbnailService.hasDiskThumbnail(documentId: docId, pageIndex: 0), isTrue);

      // Deleting document must purge thumbnails
      await documentService.deleteDocument(docId, enqueueSync: false);

      expect(await thumbnailService.hasDiskThumbnail(documentId: docId, pageIndex: 0), isFalse);
      await db.close();
    });
  });
}
