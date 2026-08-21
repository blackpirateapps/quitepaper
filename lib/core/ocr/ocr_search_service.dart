import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/search/domain/search_result.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../search/fuzzy_search_engine.dart';
import 'ocr_crypto.dart';
import 'ocr_models.dart';

/// In-memory cache entry for decrypted OCR text
class _CachedOcrPage {
  final int pageNumber;
  final String plainText;

  const _CachedOcrPage({
    required this.pageNumber,
    required this.plainText,
  });
}

/// High-performance coordinator for OCR and document global search.
///
/// Maintains an in-memory cache of decrypted document OCR text pages while
/// the notebook encryption keys are unlocked, allowing sub-millisecond full-text
/// search across multi-page scanned documents without repeated AES-GCM decryption.
class OcrSearchService {
  OcrSearchService({
    required this.database,
    required this.keyManager,
    OcrCrypto? ocrCrypto,
  })  : _ocrCrypto = ocrCrypto ?? OcrCrypto();

  final AppDatabase database;
  final KeyManager keyManager;
  final OcrCrypto _ocrCrypto;

  /// In-memory decrypted OCR text cache: documentId -> list of pages
  final Map<String, List<_CachedOcrPage>> _ocrCache = {};

  /// In-memory decrypted OCR text cache: attachmentId -> list of pages
  final Map<String, List<_CachedOcrPage>> _attachmentOcrCache = {};

  /// Invalidate cache for a specific document (e.g. on OCR retry or document deletion)
  void invalidateDocumentCache(String documentId) {
    _ocrCache.remove(documentId);
  }

  /// Invalidate cache for a specific attachment (e.g. on OCR retry or deletion)
  void invalidateAttachmentCache(String attachmentId) {
    _attachmentOcrCache.remove(attachmentId);
  }

  /// Invalidate entire in-memory cache (e.g. on notebook lock or account sign-out)
  void clearCache() {
    _ocrCache.clear();
    _attachmentOcrCache.clear();
  }

  /// Directly update cache with newly recognized OCR pages from DocumentProcessingService
  void updateDocumentCache(String documentId, List<OcrPage> pages) {
    _ocrCache[documentId] = pages
        .map((p) => _CachedOcrPage(pageNumber: p.pageNumber, plainText: p.plainText))
        .toList();
  }

  /// Directly update cache with newly recognized OCR pages from AttachmentProcessingService
  void updateAttachmentCache(String attachmentId, List<OcrPage> pages) {
    _attachmentOcrCache[attachmentId] = pages
        .map((p) => _CachedOcrPage(pageNumber: p.pageNumber, plainText: p.plainText))
        .toList();
  }

  /// Searches all active documents (attached and unattached) for matching title or OCR text
  /// with typo-tolerant fuzzy matching and relevance scoring.
  Future<List<DocumentSearchMatch>> searchDocuments(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final activeDocuments = await database.getActiveDocuments();
    if (activeDocuments.isEmpty) return const [];

    final results = <DocumentSearchMatch>[];
    final noteTitleCache = <String, String>{};

    // Pre-cache note titles for fast lookup
    final activeNotes = await (database.select(database.notesTable)
          ..where((n) => n.isTrashed.equals(false)))
        .get();
    for (final note in activeNotes) {
      noteTitleCache[note.id] = note.title.isNotEmpty ? note.title : 'Untitled Note';
    }

    final isUnlocked = keyManager.isUnlocked;
    Uint8List? masterKey;
    if (isUnlocked) {
      try {
        masterKey = keyManager.getMasterKey();
      } catch (_) {}
    }

    for (final doc in activeDocuments) {
      final docTitle = doc.title;
      final titleMatch = FuzzySearchEngine.evaluate(
        query: clean,
        text: docTitle,
        isTitle: true,
      );

      // Resolve parent note title
      String? parentNoteTitle;
      String? effectiveNoteId = doc.noteId;

      if (effectiveNoteId != null && effectiveNoteId.isNotEmpty) {
        parentNoteTitle = noteTitleCache[effectiveNoteId];
      } else {
        // Check if any active note embeds this document via markdown
        for (final note in activeNotes) {
          if (note.content.contains('qp://document/${doc.id}')) {
            effectiveNoteId = note.id;
            parentNoteTitle = note.title.isNotEmpty ? note.title : 'Untitled Note';
            break;
          }
        }
      }

      var matchedOcrPagesCount = 0;

      // Search OCR text if notebook is unlocked or cached
      List<_CachedOcrPage>? cachedPages = _ocrCache[doc.id];

      if (cachedPages == null && isUnlocked && masterKey != null) {
        // Load & decrypt document OCR pages into cache
        try {
          final ocrRows = await database.getDocumentOcrPages(doc.id);
          if (ocrRows.isNotEmpty) {
            final decryptedPages = <_CachedOcrPage>[];
            for (final row in ocrRows) {
              try {
                final encryptedBytes = base64Decode(row.encryptedPayload);
                final ocrDoc = await _ocrCrypto.decryptOcrDocument(
                  encryptedEnvelopeBytes: encryptedBytes,
                  masterKeyBytes: masterKey,
                  documentId: doc.id,
                );
                for (final p in ocrDoc.pages) {
                  decryptedPages.add(_CachedOcrPage(
                    pageNumber: p.pageNumber,
                    plainText: p.plainText,
                  ));
                }
              } catch (_) {}
            }
            _ocrCache[doc.id] = decryptedPages;
            cachedPages = decryptedPages;
          }
        } catch (_) {}
      }

      if (cachedPages != null && cachedPages.isNotEmpty) {
        for (final page in cachedPages) {
          final pageMatch = FuzzySearchEngine.evaluate(
            query: clean,
            text: page.plainText,
            isTitle: false,
          );

          if (pageMatch.hasMatch) {
            matchedOcrPagesCount++;
            final combinedScore = pageMatch.score + (titleMatch.hasMatch ? 40.0 : 0.0);

            results.add(
              DocumentSearchMatch(
                document: doc,
                parentNoteTitle: parentNoteTitle,
                parentNoteId: effectiveNoteId,
                matchedPageNumber: page.pageNumber,
                snippet: pageMatch.snippet,
                isOcrMatch: true,
                isFuzzy: pageMatch.isFuzzy,
                matchedTokensCount: pageMatch.matchedTokensCount,
                score: combinedScore,
              ),
            );
          }
        }
      }

      // If document matched via Title but had no OCR text matches on specific pages,
      // include the document as a title match
      if (titleMatch.hasMatch && matchedOcrPagesCount == 0) {
        results.add(
          DocumentSearchMatch(
            document: doc,
            parentNoteTitle: parentNoteTitle,
            parentNoteId: effectiveNoteId,
            matchedPageNumber: 1,
            snippet: 'Document Title: $docTitle',
            isOcrMatch: false,
            isFuzzy: titleMatch.isFuzzy,
            matchedTokensCount: titleMatch.matchedTokensCount,
            score: titleMatch.score,
          ),
        );
      }
    }

    // Sort document search results by descending relevance score
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }
}
