import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../attachments/cloudinary_client.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../ocr/document_processing_service.dart';
import '../ocr/ocr_models.dart';
import '../sync/sync_api_client.dart';
import '../uri/quiet_paper_uri.dart';
import '../uri/resource_resolver.dart';
import 'document_crypto.dart';
import 'document_models.dart';
import 'document_storage.dart';

/// Central coordinator for scanned and imported document storage, cryptography,
/// lifecycle, asynchronous OCR processing, and URI resolution.
class DocumentService implements DocumentResolver {
  DocumentService({
    required this.database,
    required this.keyManager,
    DocumentCrypto? crypto,
    DocumentLocalStorage? storage,
    CloudinaryClient? cloudinaryClient,
    this.processingService,
    this.apiClient,
  })  : _crypto = crypto ?? DocumentCrypto(),
        _storage = storage ?? DocumentLocalStorage(),
        _cloudinary = cloudinaryClient ?? DefaultCloudinaryClient();

  final AppDatabase database;
  final KeyManager keyManager;
  final DocumentCrypto _crypto;
  final DocumentLocalStorage _storage;
  final CloudinaryClient _cloudinary;
  final DocumentProcessingService? processingService;
  final SyncApiClient? apiClient;

  static const _uuid = Uuid();

  /// Maximum permitted PDF document byte size (50 MB).
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Creates and stores a document from canonical plaintext PDF [pdfBytes].
  ///
  /// Encrypts the PDF with the user's Master Key, persists the encrypted ciphertext (.qpd)
  /// locally, caches decrypted bytes in RAM, saves document metadata to Drift DB,
  /// triggers background OCR processing, and returns the persisted entity and canonical Markdown reference.
  Future<({DocumentEntity document, String markdownSnippet})> createDocumentFromPdfBytes({
    required Uint8List pdfBytes,
    required int pageCount,
    String? noteId,
    String title = 'Scanned Document',
    DocumentSource source = DocumentSource.scanner,
    OcrLanguage language = OcrLanguage.english,
    String? thumbnailPath,
  }) async {
    if (pdfBytes.length > maxFileSizeBytes) {
      throw ArgumentError(
        'Document exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      );
    }

    if (!keyManager.isUnlocked && keyManager.hasKeyData) {
      throw StateError(
        'Quiet Paper encryption keys are locked. Unlock notebook to create documents.',
      );
    }

    final documentId = _uuid.v4();
    final now = DateTime.now();
    final sha256Hash = DocumentCrypto.computeSha256(pdfBytes);
    final masterKey = keyManager.getMasterKey();

    // 1. Client-side authenticated encryption bound to document ID
    final encryptedBytes = await _crypto.encryptDocument(
      plaintextBytes: pdfBytes,
      masterKeyBytes: masterKey,
      documentId: documentId,
      keyVersion: 1,
    );

    // 2. Persist encrypted ciphertext locally in app-private storage (.qpd)
    final localPath = await _storage.saveEncryptedBytes(
      documentId: documentId,
      encryptedBytes: encryptedBytes,
    );

    // 3. Cache decrypted plaintext in memory for instant local viewing
    _storage.putDecryptedCache(documentId, pdfBytes);

    // 4. Save metadata to Drift database
    final cleanTitle = title.trim().isNotEmpty
        ? title.trim()
        : (source == DocumentSource.importedPdf ? 'Imported PDF' : 'Scanned Document');

    await database.saveDocument(
      id: documentId,
      noteId: noteId,
      title: cleanTitle,
      source: source.identifier,
      createdAt: now,
      updatedAt: now,
      mimeType: 'application/pdf',
      byteSize: pdfBytes.length,
      pageCount: pageCount > 0 ? pageCount : 1,
      sha256: sha256Hash,
      encryptionKeyVersion: 1,
      isDirty: true,
      isDeleted: false,
      serverRevision: 0,
      uploadState: DocumentUploadState.uploadPending.identifier,
      localPath: localPath,
      thumbnailPath: thumbnailPath,
      ocrState: OcrProcessingState.queued.identifier,
      ocrLanguage: language.code,
    );

    // 5. Enqueue background OCR / text extraction asynchronously
    if (processingService != null) {
      // Non-blocking invocation
      processingService!.processDocument(
        documentId: documentId,
        pdfBytes: pdfBytes,
        source: source,
        language: language,
      ).catchError((err) {
        debugPrint('Async document processing error: $err');
      });
    }

    final entity = await database.getDocument(documentId);
    final uri = QuietPaperUri.document(documentId).toUriString();
    final markdownSnippet = '[$cleanTitle]($uri)';

    return (document: entity!, markdownSnippet: markdownSnippet);
  }

  /// Creates and stores a web snapshot document from UTF-8 HTML [htmlBytes].
  Future<({DocumentEntity document, String markdownSnippet})> createWebSnapshotDocument({
    required Uint8List htmlBytes,
    String? noteId,
    String title = 'Web Snapshot',
  }) async {
    if (htmlBytes.length > maxFileSizeBytes) {
      throw ArgumentError(
        'Snapshot exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      );
    }

    if (!keyManager.isUnlocked && keyManager.hasKeyData) {
      throw StateError(
        'Quiet Paper encryption keys are locked. Unlock notebook to create documents.',
      );
    }

    final documentId = _uuid.v4();
    final now = DateTime.now();
    final sha256Hash = DocumentCrypto.computeSha256(htmlBytes);
    final masterKey = keyManager.getMasterKey();

    // 1. Client-side authenticated encryption bound to document ID
    final encryptedBytes = await _crypto.encryptDocument(
      plaintextBytes: htmlBytes,
      masterKeyBytes: masterKey,
      documentId: documentId,
      keyVersion: 1,
    );

    // 2. Persist encrypted ciphertext locally in app-private storage (.qpd)
    final localPath = await _storage.saveEncryptedBytes(
      documentId: documentId,
      encryptedBytes: encryptedBytes,
    );

    // 3. Cache decrypted plaintext in memory for instant local viewing
    _storage.putDecryptedCache(documentId, htmlBytes);

    // 4. Save metadata to Drift database
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : 'Web Snapshot';

    await database.saveDocument(
      id: documentId,
      noteId: noteId,
      title: cleanTitle,
      source: DocumentSource.webSnapshot.identifier,
      createdAt: now,
      updatedAt: now,
      mimeType: 'text/html',
      byteSize: htmlBytes.length,
      pageCount: 1,
      sha256: sha256Hash,
      encryptionKeyVersion: 1,
      isDirty: true,
      isDeleted: false,
      serverRevision: 0,
      uploadState: DocumentUploadState.uploadPending.identifier,
      localPath: localPath,
      thumbnailPath: null,
      ocrState: OcrProcessingState.available.identifier,
      ocrLanguage: 'en',
    );

    final entity = await database.getDocument(documentId);
    final uri = QuietPaperUri.document(documentId).toUriString();
    final markdownSnippet = '[$cleanTitle]($uri)';

    return (document: entity!, markdownSnippet: markdownSnippet);
  }

  /// Imports an existing local PDF file as a canonical Quiet Paper document.
  Future<({DocumentEntity document, String markdownSnippet})> importPdfFile({
    required File file,
    String? noteId,
    String? title,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    if (!await file.exists()) {
      throw ArgumentError('Selected PDF file does not exist: ${file.path}');
    }

    final pdfBytes = await file.readAsBytes();
    if (pdfBytes.length > maxFileSizeBytes) {
      throw ArgumentError(
        'Document exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      );
    }

    // Estimate page count by counting /Type /Page occurrences in PDF structure
    final pdfContent = String.fromCharCodes(pdfBytes);
    final pageMatches = RegExp(r'/Type\s*/Page\b').allMatches(pdfContent).toList();
    final estimatedPages = pageMatches.isNotEmpty ? pageMatches.length : 1;

    final documentTitle = title != null && title.trim().isNotEmpty
        ? title.trim()
        : p.basenameWithoutExtension(file.path);

    return createDocumentFromPdfBytes(
      pdfBytes: pdfBytes,
      pageCount: estimatedPages,
      noteId: noteId,
      title: documentTitle,
      source: DocumentSource.importedPdf,
      language: language,
    );
  }

  /// Renames a document and updates its metadata in the database.
  /// If the document is attached to a note ([noteId] or looked up from DB),
  /// it also updates any markdown link references `[oldTitle](qp://document/<documentId>)`
  /// in the note content.
  Future<void> renameDocument({
    required String documentId,
    required String newTitle,
    String? noteId,
  }) async {
    final cleanTitle = newTitle.trim();
    if (cleanTitle.isEmpty) return;

    // 1. Update title in documents database table
    await database.updateDocumentTitle(documentId, cleanTitle);

    // 2. Look up the document to find associated noteId if not provided
    final doc = await database.getDocument(documentId);
    final targetNoteId = noteId ?? doc?.noteId;

    // 3. If note is found, replace markdown link title in the note's content
    if (targetNoteId != null && targetNoteId.isNotEmpty) {
      final noteWithTags = await database.getNoteWithTags(targetNoteId);
      if (noteWithTags != null) {
        final note = noteWithTags.note;
        final regex = RegExp(
          r'\[([^\]\n]*)\]\(qp:\/\/document\/' + RegExp.escape(documentId) + r'(\?[^\)]*)?\)',
        );
        if (regex.hasMatch(note.content)) {
          final updatedContent = note.content.replaceAllMapped(regex, (match) {
            final queryPart = match.group(2) ?? '';
            return '[$cleanTitle](qp://document/$documentId$queryPart)';
          });
          if (updatedContent != note.content) {
            await database.saveNote(
              id: note.id,
              title: note.title,
              content: updatedContent,
              createdAt: note.createdAt,
              updatedAt: DateTime.now(),
              isPinned: note.isPinned,
              isArchived: note.isArchived,
              isTrashed: note.isTrashed,
              deletedAt: note.deletedAt,
              tags: noteWithTags.tagNames,
            );
          }
        }
      }
    }
  }

  /// Gets decrypted structured OCR document data if available.
  Future<OcrDocument?> getOcrDocument(String documentId) async {
    if (processingService != null) {
      return processingService!.getDecryptedOcrDocument(documentId);
    }
    return null;
  }

  // ==========================================
  // DOCUMENT RESOLVER IMPLEMENTATION
  // ==========================================

  @override
  Future<bool> isDocumentAvailableLocally(String documentId) async {
    final cached = _storage.getDecryptedCache(documentId);
    if (cached != null) return true;
    return _storage.hasEncryptedFile(documentId: documentId);
  }

  @override
  Future<ResourceResolution<ResolvedDocumentInfo>> resolveDocument(
    String documentId,
  ) async {
    final uri = QuietPaperUri.document(documentId);

    // 1. Check local database record, or fetch remote metadata from backend on demand
    var entity = await database.getDocument(documentId);

    final client = apiClient;
    if ((entity == null || entity.cloudUrl == null || entity.cloudUrl!.isEmpty) &&
        client != null) {
      try {
        final remotePayload = await client.getDocumentMetadata(documentId);
        if (remotePayload != null) {
          await database.saveDocument(
            id: remotePayload.id,
            noteId: remotePayload.noteId,
            title: remotePayload.title,
            source: remotePayload.source.identifier,
            createdAt: remotePayload.createdAt,
            updatedAt: remotePayload.updatedAt,
            mimeType: remotePayload.mimeType,
            byteSize: remotePayload.byteSize,
            pageCount: remotePayload.pageCount,
            sha256: remotePayload.sha256,
            encryptionKeyVersion: remotePayload.encryptionKeyVersion,
            serverRevision: remotePayload.serverRevision,
            isDirty: false,
            isDeleted: remotePayload.isDeleted,
            deletedAt: remotePayload.deletedAt,
            uploadState: 'synced',
            cloudPublicId: remotePayload.cloudPublicId,
            cloudUrl: remotePayload.cloudUrl,
            ocrState: remotePayload.ocrState.identifier,
            ocrLanguage: remotePayload.ocrLanguage,
          );
          entity = await database.getDocument(documentId);
        }
      } catch (metaErr) {
        debugPrint('Failed to query remote metadata for document $documentId: $metaErr');
      }
    }

    if (entity == null || entity.isDeleted) {
      return ResourceResolution.missing(uri, 'Document not found or deleted');
    }

    // 2. Check ephemeral in-memory cache
    final memCached = _storage.getDecryptedCache(documentId);
    if (memCached != null) {
      return ResourceResolution.available(
        uri,
        ResolvedDocumentInfo(
          documentId: documentId,
          pdfBytes: memCached,
          pageCount: entity.pageCount,
          byteSize: entity.byteSize,
          sha256: entity.sha256,
          title: entity.title,
          noteId: entity.noteId,
          source: entity.source,
          ocrState: entity.ocrState,
          ocrLanguage: entity.ocrLanguage,
        ),
      );
    }

    // 3. Check encryption unlock status
    if (!keyManager.isUnlocked && keyManager.hasKeyData) {
      return ResourceResolution.locked(
        uri,
        'Quiet Paper encryption password required to unlock document',
      );
    }

    final masterKey = keyManager.getMasterKey();

    // 4. Read local encrypted ciphertext
    var encryptedBytes = await _storage.readEncryptedBytes(
      documentId: documentId,
      localPath: entity.localPath,
    );

    // 5. If missing locally on disk but cloudUrl exists, download directly from Cloudinary
    if (encryptedBytes == null && entity.cloudUrl != null && entity.cloudUrl!.isNotEmpty) {
      try {
        encryptedBytes = await _cloudinary.downloadEncryptedBytes(
          cloudUrl: entity.cloudUrl!,
        );

        // Save downloaded ciphertext to local storage
        final savedPath = await _storage.saveEncryptedBytes(
          documentId: documentId,
          encryptedBytes: encryptedBytes,
        );

        await database.updateDocumentUploadState(
          documentId,
          entity.uploadState,
          localPath: savedPath,
        );
      } catch (dlErr) {
        return ResourceResolution.error(
          uri,
          'Failed to download document from cloud: $dlErr',
        );
      }
    }

    if (encryptedBytes == null) {
      return ResourceResolution.missing(uri, 'Encrypted document file missing from disk');
    }

    // 6. Decrypt ciphertext using Master Key
    try {
      final decrypted = await _crypto.decryptDocument(
        encryptedEnvelopeBytes: encryptedBytes,
        masterKeyBytes: masterKey,
        documentId: documentId,
      );

      // Verify integrity against stored SHA-256
      if (entity.sha256.isNotEmpty) {
        final hash = DocumentCrypto.computeSha256(decrypted);
        if (hash != entity.sha256) {
          return ResourceResolution.corrupted(
            uri,
            'Document SHA-256 integrity verification failed',
          );
        }
      }

      // Cache decrypted bytes in memory
      _storage.putDecryptedCache(documentId, decrypted);

      return ResourceResolution.available(
        uri,
        ResolvedDocumentInfo(
          documentId: documentId,
          pdfBytes: decrypted,
          pageCount: entity.pageCount,
          byteSize: entity.byteSize,
          sha256: entity.sha256,
          title: entity.title,
          noteId: entity.noteId,
          source: entity.source,
          ocrState: entity.ocrState,
          ocrLanguage: entity.ocrLanguage,
        ),
      );
    } catch (decErr) {
      return ResourceResolution.corrupted(
        uri,
        'Document decryption failed: $decErr',
      );
    }
  }

  /// Deletes a document record and queues sync tombstone.
  Future<void> deleteDocument(String documentId, {bool enqueueSync = true}) async {
    _storage.invalidateDecryptedCache(documentId);
    await database.deleteDocument(documentId, enqueueSync: enqueueSync);
    await database.deleteDocumentOcrPages(documentId);
    await _storage.deleteEncryptedFile(documentId: documentId);
  }

  /// Watches all active documents for a note.
  Stream<List<DocumentEntity>> watchDocumentsForNote(String noteId) {
    return database.watchDocumentsForNote(noteId);
  }

  /// Gets all active documents for a note.
  Future<List<DocumentEntity>> getDocumentsForNote(String noteId) {
    return database.getDocumentsForNote(noteId);
  }
}
