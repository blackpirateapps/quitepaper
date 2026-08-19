import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import 'attachment_models.dart';
import 'attachment_storage.dart';
import 'cloudinary_client.dart';

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
  Future<void> syncPendingAttachments() async {
    if (_isUploading) return;
    if (authService.currentUser == null || !keyManager.isUnlocked) return;

    _isUploading = true;

    try {
      final pendingList = await database.getPendingUploadAttachments();
      if (pendingList.isEmpty) return;

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
            debugPrint('Encrypted payload missing locally for attachment ${item.id}');
            await database.updateAttachmentUploadState(
              item.id,
              AttachmentUploadState.failed.identifier,
            );
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
        } catch (e) {
          debugPrint('Failed to upload attachment ${item.id} to Cloudinary: $e');
          await database.updateAttachmentUploadState(
            item.id,
            AttachmentUploadState.failed.identifier,
          );
        }
      }
    } catch (e) {
      debugPrint('Error running attachment sync loop: $e');
    } finally {
      _isUploading = false;
    }
  }
}
