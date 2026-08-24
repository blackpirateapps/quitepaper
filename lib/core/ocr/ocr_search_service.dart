import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
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

  /// In-memory cached candidate DTO list for instantaneous (0ms) global search candidate retrieval
  List<OcrPageCandidateDto>? _cachedCandidates;

  /// Invalidate cache for a specific document (e.g. on OCR retry or document deletion)
  void invalidateDocumentCache(String documentId) {
    _ocrCache.remove(documentId);
    _cachedCandidates = null;
  }

  /// Invalidate cache for a specific attachment (e.g. on OCR retry or deletion)
  void invalidateAttachmentCache(String attachmentId) {
    _attachmentOcrCache.remove(attachmentId);
    _cachedCandidates = null;
  }

  /// Invalidate entire in-memory cache (e.g. on notebook lock or account sign-out)
  void clearCache() {
    _ocrCache.clear();
    _attachmentOcrCache.clear();
    _cachedCandidates = null;
  }

  /// Directly update cache with newly recognized OCR pages from DocumentProcessingService
  void updateDocumentCache(String documentId, List<OcrPage> pages) {
    _ocrCache[documentId] = pages
        .map((p) => _CachedOcrPage(pageNumber: p.pageNumber, plainText: p.plainText))
        .toList();
    _cachedCandidates = null;
  }

  /// Directly update cache with newly recognized OCR pages from AttachmentProcessingService
  void updateAttachmentCache(String attachmentId, List<OcrPage> pages) {
    _attachmentOcrCache[attachmentId] = pages
        .map((p) => _CachedOcrPage(pageNumber: p.pageNumber, plainText: p.plainText))
        .toList();
    _cachedCandidates = null;
  }

  /// Retrieves lightweight isolate-safe OCR page candidate DTOs for background worker evaluation.
  /// Returns in 0ms on cache hits without database queries or main-thread cryptographic overhead.
  Future<List<OcrPageCandidateDto>> getOcrPageCandidates() async {
    if (_cachedCandidates != null) {
      return _cachedCandidates!;
    }

    final activeDocuments = await database.getActiveDocuments();
    final activeAttachments = await database.getActiveAttachments();
    if (activeDocuments.isEmpty && activeAttachments.isEmpty) {
      _cachedCandidates = const [];
      return _cachedCandidates!;
    }

    final candidates = <OcrPageCandidateDto>[];
    final noteTitleCache = <String, String>{};

    // Efficiently query only the parent notes referenced by active documents and attachments
    final referencedNoteIds = <String>{
      for (final d in activeDocuments)
        if (d.noteId != null && d.noteId!.isNotEmpty) d.noteId!,
      for (final a in activeAttachments)
        if (a.noteId != null && a.noteId!.isNotEmpty) a.noteId!,
    };

    if (referencedNoteIds.isNotEmpty) {
      final parentNotes = await (database.select(database.notesTable)
            ..where((n) => n.id.isIn(referencedNoteIds) & n.isTrashed.equals(false)))
          .get();
      for (final note in parentNotes) {
        noteTitleCache[note.id] = note.title.isNotEmpty ? note.title : 'Untitled Note';
      }
    }

    final isUnlocked = keyManager.isUnlocked;
    Uint8List? masterKey;
    if (isUnlocked) {
      try {
        masterKey = keyManager.getMasterKey();
      } catch (_) {}
    }

    // 1. Process Document OCR pages (PDFs)
    for (final doc in activeDocuments) {
      final parentNoteTitle = doc.noteId != null ? noteTitleCache[doc.noteId] : null;
      final effectiveNoteId = doc.noteId;

      List<_CachedOcrPage>? cachedPages = _ocrCache[doc.id];
      if (cachedPages == null && isUnlocked && masterKey != null) {
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
                  shallow: true,
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
          candidates.add(
            OcrPageCandidateDto(
              documentId: doc.id,
              pageNumber: page.pageNumber,
              plainText: page.plainText,
              documentTitle: doc.title,
              parentNoteTitle: parentNoteTitle,
              parentNoteId: effectiveNoteId,
            ),
          );
        }
      } else {
        candidates.add(
          OcrPageCandidateDto(
            documentId: doc.id,
            pageNumber: 1,
            plainText: '',
            documentTitle: doc.title,
            parentNoteTitle: parentNoteTitle,
            parentNoteId: effectiveNoteId,
          ),
        );
      }
    }

    // 2. Process Attachment OCR pages (Images / Receipts / Photos)
    for (final att in activeAttachments) {
      final parentNoteTitle = att.noteId != null ? noteTitleCache[att.noteId] : null;
      final effectiveNoteId = att.noteId;

      List<_CachedOcrPage>? cachedPages = _attachmentOcrCache[att.id];
      if (cachedPages == null && isUnlocked && masterKey != null) {
        try {
          final ocrRows = await database.getAttachmentOcrPages(att.id);
          if (ocrRows.isNotEmpty) {
            final decryptedPages = <_CachedOcrPage>[];
            for (final row in ocrRows) {
              try {
                final encryptedBytes = base64Decode(row.encryptedPayload);
                final ocrDoc = await _ocrCrypto.decryptOcrDocument(
                  encryptedEnvelopeBytes: encryptedBytes,
                  masterKeyBytes: masterKey,
                  documentId: att.id,
                  shallow: true,
                );
                for (final p in ocrDoc.pages) {
                  decryptedPages.add(_CachedOcrPage(
                    pageNumber: p.pageNumber,
                    plainText: p.plainText,
                  ));
                }
              } catch (_) {}
            }
            _attachmentOcrCache[att.id] = decryptedPages;
            cachedPages = decryptedPages;
          }
        } catch (_) {}
      }

      if (cachedPages != null && cachedPages.isNotEmpty) {
        for (final page in cachedPages) {
          candidates.add(
            OcrPageCandidateDto(
              documentId: '',
              attachmentId: att.id,
              pageNumber: page.pageNumber,
              plainText: page.plainText,
              documentTitle: 'Image Attachment',
              parentNoteTitle: parentNoteTitle,
              parentNoteId: effectiveNoteId,
            ),
          );
        }
      }
    }

    _cachedCandidates = List.unmodifiable(candidates);
    return _cachedCandidates!;
  }

  /// Searches all active documents and attachments for matching title or OCR text
  /// with typo-tolerant fuzzy matching and relevance scoring.
  Future<List<DocumentSearchMatch>> searchDocuments(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final activeDocuments = await database.getActiveDocuments();
    final activeAttachments = await database.getActiveAttachments();
    if (activeDocuments.isEmpty && activeAttachments.isEmpty) return const [];

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

    // 1. Search PDF Documents
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
                  shallow: true,
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

    // 2. Search Image Attachments OCR
    for (final att in activeAttachments) {
      String? parentNoteTitle;
      String? effectiveNoteId = att.noteId;

      if (effectiveNoteId != null && effectiveNoteId.isNotEmpty) {
        parentNoteTitle = noteTitleCache[effectiveNoteId];
      } else {
        for (final note in activeNotes) {
          if (note.content.contains('qp://asset/${att.id}') ||
              note.content.contains('qp://attachment/${att.id}')) {
            effectiveNoteId = note.id;
            parentNoteTitle = note.title.isNotEmpty ? note.title : 'Untitled Note';
            break;
          }
        }
      }

      List<_CachedOcrPage>? cachedPages = _attachmentOcrCache[att.id];
      if (cachedPages == null && isUnlocked && masterKey != null) {
        try {
          final ocrRows = await database.getAttachmentOcrPages(att.id);
          if (ocrRows.isNotEmpty) {
            final decryptedPages = <_CachedOcrPage>[];
            for (final row in ocrRows) {
              try {
                final encryptedBytes = base64Decode(row.encryptedPayload);
                final ocrDoc = await _ocrCrypto.decryptOcrDocument(
                  encryptedEnvelopeBytes: encryptedBytes,
                  masterKeyBytes: masterKey,
                  documentId: att.id,
                  shallow: true,
                );
                for (final p in ocrDoc.pages) {
                  decryptedPages.add(_CachedOcrPage(
                    pageNumber: p.pageNumber,
                    plainText: p.plainText,
                  ));
                }
              } catch (_) {}
            }
            _attachmentOcrCache[att.id] = decryptedPages;
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
            results.add(
              DocumentSearchMatch(
                attachment: att,
                title: 'Image Attachment',
                parentNoteTitle: parentNoteTitle,
                parentNoteId: effectiveNoteId,
                matchedPageNumber: page.pageNumber,
                snippet: pageMatch.snippet,
                isOcrMatch: true,
                isFuzzy: pageMatch.isFuzzy,
                matchedTokensCount: pageMatch.matchedTokensCount,
                score: pageMatch.score,
              ),
            );
          }
        }
      }
    }

    // Sort document search results by descending relevance score
    results.sort((a, b) => b.score.compareTo(a.score));

    return results;
  }
}
