import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../crypto/key_manager.dart';
import '../../database/app_database.dart';
import 'annotation_crypto.dart';
import 'annotation_models.dart';

/// Loads and persists the encrypted per-page annotation sidecar (spec §4.2).
///
/// Mirrors the OCR storage path: guard [KeyManager.isUnlocked], fetch the
/// master key, encrypt/decrypt one page's annotation list through
/// [AnnotationCrypto], and upsert/read the `document_annotations` Drift row.
/// Page numbers are stored 1-based to match the OCR page table; the public API
/// uses 0-based [pageIndex].
class DocumentAnnotationService {
  DocumentAnnotationService({
    required this.database,
    required this.keyManager,
    AnnotationCrypto? crypto,
  }) : _crypto = crypto ?? AnnotationCrypto();

  final AppDatabase database;
  final KeyManager keyManager;
  final AnnotationCrypto _crypto;

  /// Decrypts and returns the annotations for a single page. Returns an empty
  /// list when locked, missing, or on a decrypt error (degrade gracefully).
  Future<List<Annotation>> loadPage(String documentId, int pageIndex) async {
    if (!keyManager.isUnlocked) return const [];
    final row =
        await database.getDocumentAnnotationPage(documentId, pageIndex + 1);
    if (row == null) return const [];
    try {
      final masterKey = keyManager.getMasterKey();
      final bytes = base64Decode(row.encryptedPayload);
      return await _crypto.decryptPage(
        encryptedEnvelopeBytes: Uint8List.fromList(bytes),
        masterKeyBytes: masterKey,
        documentId: documentId,
        pageIndex: pageIndex,
      );
    } catch (e) {
      debugPrint('[Annotations] Failed to decrypt page $pageIndex: $e');
      return const [];
    }
  }

  /// Encrypts and persists a page's annotation list (including tombstones so
  /// deletes survive a reload). [markDirty] queues the page for sync (§9).
  Future<void> savePage({
    required String documentId,
    required int pageIndex,
    required List<Annotation> annotations,
    bool markDirty = true,
  }) async {
    if (!keyManager.isUnlocked) return;
    final masterKey = keyManager.getMasterKey();
    final bytes = await _crypto.encryptPage(
      documentId: documentId,
      pageIndex: pageIndex,
      annotations: annotations,
      masterKeyBytes: masterKey,
    );
    final liveCount = annotations.where((a) => !a.deleted).length;
    await database.saveDocumentAnnotationPage(
      documentId: documentId,
      pageNumber: pageIndex + 1,
      encryptedPayload: base64Encode(bytes),
      annotationCount: liveCount,
      isDirty: markDirty,
      updatedAt: DateTime.now(),
    );
  }

  /// Map of 0-based page index → live annotation count, for badges/thumbnails
  /// without decrypting any payload.
  Future<Map<int, int>> loadPageCounts(String documentId) async {
    final rows = await database.getDocumentAnnotationPages(documentId);
    return {
      for (final r in rows)
        if (r.annotationCount > 0) r.pageNumber - 1: r.annotationCount,
    };
  }

  /// Whether the document has any (non-deleted) annotations anywhere — used to
  /// decide whether export must flatten (§8).
  Future<bool> hasAnnotations(String documentId) async {
    final rows = await database.getDocumentAnnotationPages(documentId);
    return rows.any((r) => r.annotationCount > 0);
  }

  /// Decrypts every annotated page, keyed by 0-based page index. Used by the
  /// export/flatten pipeline (§8).
  Future<Map<int, List<Annotation>>> loadAllPages(String documentId) async {
    if (!keyManager.isUnlocked) return const {};
    final rows = await database.getDocumentAnnotationPages(documentId);
    final result = <int, List<Annotation>>{};
    for (final row in rows) {
      final pageIndex = row.pageNumber - 1;
      try {
        final masterKey = keyManager.getMasterKey();
        final bytes = base64Decode(row.encryptedPayload);
        final anns = await _crypto.decryptPage(
          encryptedEnvelopeBytes: Uint8List.fromList(bytes),
          masterKeyBytes: masterKey,
          documentId: documentId,
          pageIndex: pageIndex,
        );
        final live = anns.where((a) => !a.deleted).toList();
        if (live.isNotEmpty) result[pageIndex] = live;
      } catch (e) {
        debugPrint('[Annotations] Failed to decrypt page $pageIndex: $e');
      }
    }
    return result;
  }

  /// Deletes all annotation pages for a document (called on document delete).
  Future<void> deleteDocument(String documentId) async {
    await database.deleteDocumentAnnotations(documentId);
  }
}
