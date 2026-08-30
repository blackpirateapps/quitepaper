import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'attachment_service.dart';
import 'attachment_temp_storage.dart';
import 'attachment_type_resolver.dart';

/// Service dedicated to exporting/sharing decrypted attachment copies via native OS share sheet.
class AttachmentShareService {
  AttachmentShareService({
    required this.attachmentService,
    AttachmentTempStorage? tempStorage,
  }) : _tempStorage = tempStorage ?? AttachmentTempStorage();

  final AttachmentService attachmentService;
  final AttachmentTempStorage _tempStorage;

  /// Decrypts attachment to a temporary file and triggers native OS share sheet.
  Future<bool> shareAttachment(
    String attachmentId, {
    String? fallbackFileName,
  }) async {
    try {
      final resolution = await attachmentService.resolveAsset(attachmentId);
      if (!resolution.isAvailable || resolution.data == null) {
        return false;
      }

      final entity = await attachmentService.database.getAttachment(attachmentId);
      final fileName = entity?.fileName ?? fallbackFileName ?? 'attachment_$attachmentId';
      final mimeType = entity?.mimeType ?? AttachmentTypeResolver.inferMimeType(fileName);

      final tempFile = await _tempStorage.createTemporaryDecryptedFile(
        attachmentId: attachmentId,
        rawFileName: fileName,
        plaintextBytes: resolution.data!,
      );

      final xFile = XFile(
        tempFile.path,
        name: fileName,
        mimeType: mimeType,
      );

      await Share.shareXFiles(
        [xFile],
        subject: fileName,
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing attachment $attachmentId: $e');
      return false;
    }
  }
}
