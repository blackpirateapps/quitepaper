import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import 'attachment_models.dart';
import 'attachment_storage.dart';
import 'cloudinary_client.dart';

/// Result summary of an attachment upload sync operation.
@immutable
class AttachmentSyncResult {
  const AttachmentSyncResult({
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

/// Coordinates direct-to-Cloudinary encrypted byte uploads for pending attachments
/// and syncs attachment metadata with the Vercel backend control plane.
class AttachmentSyncService {
  AttachmentSyncService({
    required this.database,
    required this.storage,
    required this.apiClient,
    required this.cloudinaryClient,
    required this.authService,
    required this.keyManager,
  });

  final AppDatabase database;
  final AttachmentLocalStorage storage;
  final SyncApiClient apiClient;
  final CloudinaryClient cloudinaryClient;
  final AuthService authService;
  final KeyManager keyManager;

  bool _isUploading = false;

  /// Synchronizes all attachments pending upload directly to Cloudinary.
  ///
  /// Flow per attachment:
  /// 1. Request upload auth from Vercel backend (validates Firebase user + note ownership).
  /// 2. Read local encrypted ciphertext from app-private storage.
  /// 3. Upload ciphertext directly to Cloudinary (zero Vercel proxying).
  /// 4. Confirm upload metadata with Vercel backend.
  /// 5. Mark attachment state 'synced' with isDirty: false.
  Future<AttachmentSyncResult> syncPendingAttachments() async {
    if (_isUploading) {
      return const AttachmentSyncResult();
    }
    if (authService.currentUser == null || !keyManager.isUnlocked) {
      return const AttachmentSyncResult();
    }

    _isUploading = true;
    var uploadedCount = 0;
    var failedCount = 0;
    final errors = <String>[];

    try {
      final pendingList = await database.getPendingUploadAttachments();
      if (pendingList.isEmpty) {
        return const AttachmentSyncResult();
      }

      for (final item in pendingList) {
        try {
          // 1. Mark state uploading
          await database.updateAttachmentUploadState(
            item.id,
            AttachmentUploadState.uploading.identifier,
          );

          // 2. Request limited Cloudinary signed upload parameters from Vercel control plane
          final uploadAuth = await apiClient.getAttachmentUploadAuth(
            attachmentId: item.id,
            noteId: item.noteId,
            mimeType: item.mimeType,
            byteSize: item.byteSize,
            sha256: item.sha256,
            variant: 'original',
          );

          // 3. Read encrypted bytes from local storage
          final encryptedBytes = await storage.readEncryptedBytes(
            attachmentId: item.id,
            variant: 'original',
            localPath: item.localPath,
          );

          if (encryptedBytes == null || encryptedBytes.isEmpty) {
            const missingMsg = 'Local encrypted payload missing from disk';
            debugPrint('Encrypted payload missing locally for attachment ${item.id}');
            await database.updateAttachmentUploadState(
              item.id,
              AttachmentUploadState.failed.identifier,
            );
            failedCount++;
            errors.add('Attachment ${item.id.substring(0, 8)}: $missingMsg');
            continue;
          }

          // 4. Upload encrypted bytes DIRECTLY to Cloudinary (data plane)
          final uploadResult = await cloudinaryClient.uploadEncryptedBytes(
            encryptedBytes: encryptedBytes,
            auth: uploadAuth,
          );

          // 5. Update local record with Cloudinary cloud identifiers
          await database.updateAttachmentUploadState(
            item.id,
            AttachmentUploadState.uploaded.identifier,
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
          );

          // 6. Confirm upload metadata with Vercel backend control plane
          await apiClient.confirmAttachmentUpload(
            attachmentId: item.id,
            noteId: item.noteId,
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
            byteSize: item.byteSize,
            sha256: item.sha256,
          );

          // 7. Mark synced
          await database.markAttachmentSynced(
            id: item.id,
            serverRevision: item.serverRevision > 0 ? item.serverRevision : 1,
            syncedAt: DateTime.now(),
            cloudPublicId: uploadResult.publicId,
            cloudUrl: uploadResult.secureUrl,
          );

          uploadedCount++;
        } catch (e) {
          final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          debugPrint('Failed to upload attachment ${item.id} to Cloudinary: $errStr');
          await database.updateAttachmentUploadState(
            item.id,
            AttachmentUploadState.failed.identifier,
          );
          failedCount++;
          errors.add(errStr);
        }
      }

      return AttachmentSyncResult(
        totalPending: pendingList.length,
        uploadedCount: uploadedCount,
        failedCount: failedCount,
        errors: errors,
      );
    } catch (e) {
      final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      debugPrint('Error running attachment sync loop: $errStr');
      return AttachmentSyncResult(
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
