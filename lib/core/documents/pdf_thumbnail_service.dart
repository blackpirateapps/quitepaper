import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../crypto/key_manager.dart';
import '../pdf/pdf_page_renderer.dart';
import '../storage/app_storage_path_resolver.dart';
import 'document_crypto.dart';

/// Service responsible for rendering, encrypted disk persistence, and in-memory
/// caching of low-DPI PDF page thumbnails.
///
/// Adheres to Quiet Paper's zero-knowledge security standard: thumbnails persisted
/// to disk are encrypted client-side using XChaCha20-Poly1305 and the user's Master Key.
class PdfThumbnailService {
  PdfThumbnailService({
    required this.keyManager,
    DocumentCrypto? crypto,
    PdfPageRenderer? renderer,
    this.customDirectory,
  })  : _crypto = crypto ?? DocumentCrypto(),
        _renderer = renderer ?? const DefaultPdfPageRenderer();

  final KeyManager keyManager;
  final DocumentCrypto _crypto;
  final PdfPageRenderer _renderer;
  final Directory? customDirectory;

  /// Low-DPI target for thumbnail preview rendering (~36 DPI).
  /// Yields compact raster bitmaps (10–25 KB per page) with sub-10ms render time.
  static const double thumbnailDpi = 36.0;

  /// Ephemeral in-memory cache: documentId -> (pageIndex -> PNG bytes).
  final Map<String, Map<int, Uint8List>> _memoryCache = {};

  /// In-flight thumbnail generation jobs to deduplicate concurrent requests.
  final Map<String, Future<Uint8List?>> _inFlightJobs = {};

  /// In-flight disk persistence jobs.
  final List<Future<void>> _pendingDiskWrites = [];

  /// Awaits all pending background disk writes. Useful for tests and graceful shutdown.
  Future<void> flushPendingWrites() async {
    if (_pendingDiskWrites.isNotEmpty) {
      await Future.wait(List.of(_pendingDiskWrites));
    }
  }

  /// Resolves the storage directory for a specific document's thumbnails.
  Future<Directory> getThumbnailDirectory(
    String documentId, {
    bool create = false,
  }) async {
    final root =
        customDirectory ?? await AppStoragePathResolver.getDataDirectory();
    final dir = Directory(p.join(root.path, 'pdf_thumbnails', documentId));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Builds local file path for an encrypted page thumbnail (.qpthumb).
  Future<File> _getThumbnailFile(String documentId, int pageIndex) async {
    final dir = await getThumbnailDirectory(documentId, create: false);
    return File(p.join(dir.path, 'page_$pageIndex.qpthumb'));
  }

  /// Safely resolves the current unlocked Master Key, or null if locked.
  Uint8List? _getMasterKey() {
    try {
      return keyManager.getMasterKey();
    } catch (_) {
      return null;
    }
  }

  /// Retrieves a page thumbnail via the 3-tier cache hierarchy:
  /// 1. In-memory decoded PNG cache (instant).
  /// 2. Encrypted local disk cache (.qpthumb), decrypted on-the-fly (5-15ms).
  /// 3. On-demand low-DPI rasterization via [PdfPageRenderer], encrypted and saved to disk.
  Future<Uint8List?> getPageThumbnail({
    required String documentId,
    required int pageIndex,
    required Uint8List pdfBytes,
  }) async {
    // 1. In-memory check
    final docMem = _memoryCache[documentId];
    if (docMem != null && docMem.containsKey(pageIndex)) {
      return docMem[pageIndex];
    }

    // Deduplicate concurrent requests for the exact same page
    final jobKey = '$documentId:$pageIndex';
    if (_inFlightJobs.containsKey(jobKey)) {
      return _inFlightJobs[jobKey];
    }

    final completer = Completer<Uint8List?>();
    _inFlightJobs[jobKey] = completer.future;

    _executeFetchThumbnail(
      documentId: documentId,
      pageIndex: pageIndex,
      pdfBytes: pdfBytes,
    ).then((bytes) {
      _inFlightJobs.remove(jobKey);
      completer.complete(bytes);
    }).catchError((dynamic error) {
      _inFlightJobs.remove(jobKey);
      debugPrint('[PdfThumbnailService] Error fetching thumbnail: $error');
      completer.complete(null);
    });

    return completer.future;
  }

  Future<Uint8List?> _executeFetchThumbnail({
    required String documentId,
    required int pageIndex,
    required Uint8List pdfBytes,
  }) async {
    final masterKey = _getMasterKey();
    final thumbFile = await _getThumbnailFile(documentId, pageIndex);

    // 2. Encrypted disk cache check
    if (masterKey != null && await thumbFile.exists()) {
      try {
        final encryptedEnvelope = await thumbFile.readAsBytes();
        final decryptedPng = await _crypto.decryptDocument(
          encryptedEnvelopeBytes: encryptedEnvelope,
          masterKeyBytes: masterKey,
          documentId: '$documentId:thumb:$pageIndex',
        );

        _putInMemory(documentId, pageIndex, decryptedPng);
        return decryptedPng;
      } catch (e) {
        debugPrint(
          '[PdfThumbnailService] Cache decryption failed for $documentId page $pageIndex: $e',
        );
        // Clean up corrupt/stale thumbnail file to allow fresh re-rasterization
        try {
          await thumbFile.delete();
        } catch (_) {}
      }
    }

    // 3. Low-DPI lazy rasterization
    try {
      final rendered = await _renderer.renderSinglePage(
        pdfBytes,
        pageIndex,
        dpi: thumbnailDpi,
      );

      if (rendered == null) return null;

      final pngBytes = rendered.imageBytes;
      _putInMemory(documentId, pageIndex, pngBytes);

      // Asynchronously encrypt and write to disk cache
      if (masterKey != null) {
        _saveToDiskAsync(
          file: thumbFile,
          plaintextBytes: pngBytes,
          masterKey: masterKey,
          documentId: documentId,
          pageIndex: pageIndex,
        );
      }

      return pngBytes;
    } catch (e) {
      debugPrint(
        '[PdfThumbnailService] Rasterization failed for $documentId page $pageIndex: $e',
      );
      return null;
    }
  }

  void _putInMemory(String documentId, int pageIndex, Uint8List pngBytes) {
    final docMem = _memoryCache.putIfAbsent(documentId, () => {});
    docMem[pageIndex] = pngBytes;
  }

  void _saveToDiskAsync({
    required File file,
    required Uint8List plaintextBytes,
    required Uint8List masterKey,
    required String documentId,
    required int pageIndex,
  }) {
    late final Future<void> job;
    job = Future<void>(() async {
      try {
        // Guard against saving if the document was deleted while rasterizing
        if (!_memoryCache.containsKey(documentId)) return;

        final encrypted = await _crypto.encryptDocument(
          plaintextBytes: plaintextBytes,
          masterKeyBytes: masterKey,
          documentId: '$documentId:thumb:$pageIndex',
        );

        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(encrypted, flush: true);
      } catch (e) {
        debugPrint(
          '[PdfThumbnailService] Failed to persist thumbnail to disk: $e',
        );
      } finally {
        _pendingDiskWrites.remove(job);
      }
    });
    _pendingDiskWrites.add(job);
  }

  /// Checks whether an encrypted disk thumbnail exists for [documentId] and [pageIndex].
  Future<bool> hasDiskThumbnail({
    required String documentId,
    required int pageIndex,
  }) async {
    try {
      final file = await _getThumbnailFile(documentId, pageIndex);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Clears in-memory thumbnail cache for [documentId] or all documents.
  void invalidateMemoryCache([String? documentId]) {
    if (documentId != null) {
      _memoryCache.remove(documentId);
    } else {
      _memoryCache.clear();
    }
  }

  /// Permanently removes memory cache and encrypted disk thumbnails for [documentId].
  Future<void> deleteThumbnails(String documentId) async {
    _memoryCache.remove(documentId);
    try {
      final dir = await getThumbnailDirectory(documentId, create: false);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint(
        '[PdfThumbnailService] Failed to delete thumbnails for $documentId: $e',
      );
    }
  }
}
