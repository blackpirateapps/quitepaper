import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../uri/quiet_paper_uri.dart';
import '../uri/resource_resolver.dart';
import 'attachment_crypto.dart';
import 'attachment_models.dart';
import 'attachment_storage.dart';
import 'cloudinary_client.dart';

/// Central coordinator for attachment storage, cryptography, lifecycle, and URI resolution.
class AttachmentService implements AssetResolver {
  AttachmentService({
    required this.database,
    required this.keyManager,
    AttachmentCrypto? crypto,
    AttachmentLocalStorage? storage,
    CloudinaryClient? cloudinaryClient,
  })  : _crypto = crypto ?? AttachmentCrypto(),
        _storage = storage ?? AttachmentLocalStorage(),
        _cloudinary = cloudinaryClient ?? DefaultCloudinaryClient();

  final AppDatabase database;
  final KeyManager keyManager;
  final AttachmentCrypto _crypto;
  final AttachmentLocalStorage _storage;
  final CloudinaryClient _cloudinary;

  static const _uuid = Uuid();

  /// Maximum permitted original image byte size (25 MB).
  static const int maxFileSizeBytes = 25 * 1024 * 1024;

  /// Supported image MIME types.
  static const Set<String> supportedMimeTypes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/gif',
  };

  /// Imports an image from a local [File] into the encrypted Quiet Paper notebook.
  ///
  /// Persists the encrypted ciphertext locally immediately, marks the attachment as pending sync,
  /// and returns a formatted markdown token `![alt](qp://asset/<UUID>)`.
  Future<({AttachmentEntity attachment, String markdownSnippet})> importImageFromFile(
    File file, {
    String? noteId,
    String? preferredAltText,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'image.png';

    final mimeType = _inferMimeType(fileName);

    return importImageFromBytes(
      bytes,
      mimeType: mimeType,
      noteId: noteId,
      preferredAltText: preferredAltText ?? _defaultAltText(fileName),
    );
  }

  /// Imports an image from raw plaintext [bytes] into the encrypted Quiet Paper notebook.
  Future<({AttachmentEntity attachment, String markdownSnippet})> importImageFromBytes(
    Uint8List bytes, {
    required String mimeType,
    String? noteId,
    String preferredAltText = 'Image',
  }) async {
    if (bytes.length > maxFileSizeBytes) {
      throw ArgumentError(
        'Image exceeds maximum allowed size of ${maxFileSizeBytes ~/ (1024 * 1024)} MB',
      );
    }

    if (!keyManager.isUnlocked) {
      throw StateError(
        'Quiet Paper encryption keys are locked. Unlock notebook to import attachments.',
      );
    }

    final attachmentId = _uuid.v4();
    final now = DateTime.now();
    final sha256Hash = AttachmentCrypto.computeSha256(bytes);
    final masterKey = keyManager.getMasterKey();

    // 1. Client-side authenticated encryption
    final encryptedBytes = await _crypto.encryptAttachment(
      plaintextBytes: bytes,
      masterKeyBytes: masterKey,
      attachmentId: attachmentId,
      variant: 'original',
      keyVersion: 1,
    );

    // 2. Persist encrypted ciphertext locally in app-private storage
    final localPath = await _storage.saveEncryptedBytes(
      attachmentId: attachmentId,
      encryptedBytes: encryptedBytes,
      variant: 'original',
    );

    // 3. Cache decrypted plaintext in memory for instant local rendering
    _storage.putDecryptedCache(attachmentId, bytes, variant: 'original');

    // 4. Save metadata to Drift database
    await database.saveAttachment(
      id: attachmentId,
      noteId: noteId,
      createdAt: now,
      updatedAt: now,
      mimeType: mimeType,
      byteSize: bytes.length,
      sha256: sha256Hash,
      encryptionKeyVersion: 1,
      isDirty: true,
      isDeleted: false,
      serverRevision: 0,
      uploadState: AttachmentUploadState.uploadPending.identifier,
      localPath: localPath,
    );

    final entity = await database.getAttachment(attachmentId);
    final cleanAlt = preferredAltText.replaceAll('[', '').replaceAll(']', '').trim();
    final uri = QuietPaperUri.asset(attachmentId).toUriString();
    final markdownSnippet = '![$cleanAlt]($uri)';

    return (attachment: entity!, markdownSnippet: markdownSnippet);
  }

  // ==========================================
  // RESOURCE RESOLVER IMPLEMENTATION
  // ==========================================

  @override
  Future<bool> isAssetAvailableLocally(String assetId) async {
    final cached = _storage.getDecryptedCache(assetId);
    if (cached != null) return true;
    return _storage.hasEncryptedFile(attachmentId: assetId);
  }

  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String assetId, {
    String variant = 'original',
  }) async {
    final uri = QuietPaperUri.asset(assetId, parameters: {'variant': variant});

    // 1. Check ephemeral in-memory cache
    final memCached = _storage.getDecryptedCache(assetId, variant: variant);
    if (memCached != null) {
      return ResourceResolution.available(uri, memCached);
    }

    // 2. Check local database record
    final entity = await database.getAttachment(assetId);
    if (entity == null || entity.isDeleted) {
      return ResourceResolution.missing(uri, 'Attachment not found or deleted');
    }

    // 3. Check encryption unlock status
    if (!keyManager.isUnlocked) {
      return ResourceResolution.locked(
        uri,
        'Quiet Paper encryption password required to view encrypted attachment',
      );
    }

    final masterKey = keyManager.getMasterKey();

    // 4. Read local encrypted ciphertext
    var encryptedBytes = await _storage.readEncryptedBytes(
      attachmentId: assetId,
      variant: variant,
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
          attachmentId: assetId,
          encryptedBytes: encryptedBytes,
          variant: variant,
        );

        await database.updateAttachmentUploadState(
          assetId,
          entity.uploadState,
          localPath: savedPath,
        );
      } catch (dlErr) {
        return ResourceResolution.error(
          uri,
          'Failed to download attachment from cloud: $dlErr',
        );
      }
    }

    if (encryptedBytes == null) {
      return ResourceResolution.missing(uri, 'Encrypted attachment file missing');
    }

    // 6. Decrypt ciphertext using Master Key
    try {
      final decrypted = await _crypto.decryptAttachment(
        encryptedEnvelopeBytes: encryptedBytes,
        masterKeyBytes: masterKey,
        attachmentId: assetId,
        variant: variant,
      );

      // Verify integrity against stored SHA-256 if original variant
      if (variant == 'original' && entity.sha256.isNotEmpty) {
        final hash = AttachmentCrypto.computeSha256(decrypted);
        if (hash != entity.sha256) {
          return ResourceResolution.corrupted(
            uri,
            'Attachment SHA-256 integrity verification failed',
          );
        }
      }

      // Cache decrypted bytes in memory
      _storage.putDecryptedCache(assetId, decrypted, variant: variant);

      return ResourceResolution.available(uri, decrypted);
    } catch (decErr) {
      return ResourceResolution.corrupted(
        uri,
        'Attachment decryption failed: $decErr',
      );
    }
  }

  /// Deletes an attachment record and queues sync tombstone.
  Future<void> deleteAttachment(String assetId, {bool enqueueSync = true}) async {
    _storage.invalidateDecryptedCache(assetId);
    await database.deleteAttachment(assetId, enqueueSync: enqueueSync);
    await _storage.deleteEncryptedFile(attachmentId: assetId);
  }

  /// Watches all active attachments for a note.
  Stream<List<AttachmentEntity>> watchAttachmentsForNote(String noteId) {
    return database.watchAttachmentsForNote(noteId);
  }

  /// Gets all active attachments for a note.
  Future<List<AttachmentEntity>> getAttachmentsForNote(String noteId) {
    return database.getAttachmentsForNote(noteId);
  }

  // ==========================================
  // HELPERS
  // ==========================================

  static String _inferMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }

  static String _defaultAltText(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex > 0) {
      return fileName.substring(0, dotIndex);
    }
    return fileName.isNotEmpty ? fileName : 'Image';
  }
}
