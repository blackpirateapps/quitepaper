import 'package:flutter/foundation.dart';
import '../attachments/cloudinary_client.dart';
import '../auth/auth_service.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import 'document_models.dart';
import 'document_storage.dart';

/// Result summary of a scanned document upload sync operation.
@immutable
class DocumentSyncResult {
  const DocumentSyncResult({
    this.totalPending = 0,
    this.uploadedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });

  final int totalPending;
  final int uploadedCount;
  final int failedCount;
  final List<String> errors;

  bool get hasErrors => failedCount > 0 || errors.isNotEmpty;
  bool get hasUploaded => uploadedCount > 0;
}

/// Coordinates direct-to-Cloudinary encrypted PDF uploads for pending scanned documents
/// and syncs document metadata with the Vercel backend control plane.
class DocumentSyncService {
  DocumentSyncService({
    required this.database,
    required this.storage,
    required this.apiClient,
    required this.cloudinaryClient,
    required this.authService,
    required this.keyManager,
  });

  final AppDatabase database;
  final DocumentLocalStorage storage;
  final SyncApiClient apiClient;
  final CloudinaryClient cloudinaryClient;
  final AuthService authService;
  final KeyManager keyManager;

  bool _isUploading = false;

  /// Synchronizes all scanned documents pending upload directly to Cloudinary.
  ///
  /// Flow per document:
  /// 1. Request upload auth from Vercel backend (validates Firebase user + note ownership).
  /// 2. Read local encrypted ciphertext from app-private storage (.qpd).
  /// 3. Upload ciphertext directly to Cloudinary (zero Vercel proxying).
  /// 4. Confirm upload metadata with Vercel backend.
  /// 5. Mark document state 'synced' with isDirty: false.
  Future<DocumentSyncResult> syncPendingDocuments() async {
    if (_isUploading) {
      return const DocumentSyncResult();
    }
    if (authService.currentUser == null || !keyManager.isUnlocked) {
      return const DocumentSyncResult();
    }

    _isUploading = true;
    var uploadedCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    try {
      final pendingList = await database.getPendingUploadDocuments();
      if (pendingList.isEmpty) {
        return const DocumentSyncResult();
      }

      for (final item in pendingList) {
        try {
          // 1. Mark state uploading
          await database.updateDocumentUploadState(
            item.id,
            DocumentUploadState.uploading.identifier,
          );

          // 2. Request limited Cloudinary signed upload parameters from Vercel control plane
          final uploadAuth = await apiClient.getDocumentUploadAuth(
            documentId: item.id,
            noteId: item.noteId,
            title: item.title,
            source: item.source,
            mimeType: item.mimeType,
            byteSize: item.byteSize,
            pageCount: item.pageCount,
            sha256: item.sha256,
          );

          // 3. Read encrypted bytes from local storage
          final encryptedBytes = await storage.readEncryptedBytes(
            documentId: item.id,
            localPath: item.localPath,
          );

          if (encryptedBytes == null || encryptedBytes.isEmpty) {
            const missingMsg = 'Local encrypted payload missing from disk';
            debugPrint('Encrypted payload missing locally for document ${item.id}');
            await database.updateDocumentUploadState(
              item.id,
              DocumentUploadState.failed.identifier,
            );
            failedCount++;
            errors.add('Document ${item.id.substring(0, 8)}: $missingMsg');
            continue;
          }

          // 4. Upload encrypted bytes DIRECTLY to Cloudinary (data plane)
          final uploadResult = await cloudinaryClient.uploadEncryptedBytes(
            encryptedBytes: encryptedBytes,
            auth: uploadAuth,
          );

          // 5. Update local record with Cloudinary cloud identifiers
          await database.updateDocumentUploadState(
            item.id,
            DocumentUploadState.uploaded.identifier,
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
          );

          // 6. Confirm upload metadata with Vercel backend control plane
          await apiClient.confirmDocumentUpload(
            documentId: item.id,
            noteId: item.noteId,
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
            title: item.title,
            source: item.source,
            mimeType: item.mimeType,
            byteSize: item.byteSize,
            pageCount: item.pageCount,
            sha256: item.sha256,
            ocrState: item.ocrState,
            ocrLanguage: item.ocrLanguage,
          );

          // 7. Mark synced
          await database.markDocumentSynced(
            id: item.id,
            serverRevision: item.serverRevision > 0 ? item.serverRevision : 1,
            syncedAt: DateTime.now(),
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
          );

          uploadedCount++;
        } catch (e) {
          final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          debugPrint('Failed to upload document ${item.id} to Cloudinary: $errStr');
          await database.updateDocumentUploadState(
            item.id,
            DocumentUploadState.failed.identifier,
          );
          failedCount++;
          errors.add(errStr);
        }
      }

      return DocumentSyncResult(
        totalPending: pendingList.length,
        uploadedCount: uploadedCount,
        failedCount: failedCount,
        errors: errors,
      );
    } catch (e) {
      final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      debugPrint('Error running document sync loop: $errStr');
      return DocumentSyncResult(
        totalPending: 0,
        uploadedCount: uploadedCount,
        failedCount: failedCount + 1,
        errors: [errStr],
      );
    } finally {
      _isUploading = false;
    }
  }
}
