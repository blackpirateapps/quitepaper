import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../attachments/cloudinary_client.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import '../uri/quiet_paper_uri.dart';
import '../uri/resource_resolver.dart';
import 'document_crypto.dart';
import 'document_models.dart';
import 'document_storage.dart';

/// Central coordinator for scanned document storage, cryptography, lifecycle, and URI resolution.
class DocumentService implements DocumentResolver {
  DocumentService({
    required this.database,
    required this.keyManager,
    DocumentCrypto? crypto,
    DocumentLocalStorage? storage,
    CloudinaryClient? cloudinaryClient,
    this.apiClient,
  })  : _crypto = crypto ?? DocumentCrypto(),
        _storage = storage ?? DocumentLocalStorage(),
        _cloudinary = cloudinaryClient ?? DefaultCloudinaryClient();

  final AppDatabase database;
  final KeyManager keyManager;
  final DocumentCrypto _crypto;
  final DocumentLocalStorage _storage;
  final CloudinaryClient _cloudinary;
  final SyncApiClient? apiClient;

  static const _uuid = Uuid();

  /// Maximum permitted PDF document byte size (50 MB).
  static const int maxFileSizeBytes = 50 * 1024 * 1024;

  /// Creates and stores a scanned document from canonical plaintext PDF [pdfBytes].
  ///
  /// Encrypts the PDF with the user's Master Key, persists the encrypted ciphertext (.qpd)
  /// locally, caches decrypted bytes in RAM, saves document metadata to Drift DB,
  /// and returns the persisted entity and canonical Markdown reference `[Title](qp://document/<UUID>)`.
  Future<({DocumentEntity document, String markdownSnippet})> createDocumentFromPdfBytes({
    required Uint8List pdfBytes,
    required int pageCount,
    String? noteId,
    String title = 'Scanned Document',
    String? thumbnailPath,
  }) async {
    if (pdfBytes.length > maxFileSizeBytes) {
      throw ArgumentError(
        'Document exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      );
    }

    if (!keyManager.isUnlocked) {
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
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : 'Scanned Document';

    await database.saveDocument(
      id: documentId,
      noteId: noteId,
      title: cleanTitle,
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
    );

    final entity = await database.getDocument(documentId);
    final uri = QuietPaperUri.document(documentId).toUriString();
    final markdownSnippet = '[$cleanTitle]($uri)';

    return (document: entity!, markdownSnippet: markdownSnippet);
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
        ),
      );
    }

    // 3. Check encryption unlock status
    if (!keyManager.isUnlocked) {
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
