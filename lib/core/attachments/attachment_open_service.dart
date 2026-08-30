import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'attachment_service.dart';
import 'attachment_temp_storage.dart';
import 'attachment_type_resolver.dart';

/// Result of an attachment open attempt.
enum AttachmentOpenStatus {
  opened,
  missingOrUnavailable,
  decryptionFailed,
  failed,
}

/// Service dedicated to preparing temporary decrypted files and handing them off
/// to the native operating system viewer/app.
class AttachmentOpenService {
  AttachmentOpenService({
    required this.attachmentService,
    AttachmentTempStorage? tempStorage,
    MethodChannel? platformChannel,
  })  : _tempStorage = tempStorage ?? AttachmentTempStorage(),
        _platformChannel = platformChannel ?? const MethodChannel('com.blackpiratex.quietpaper/updater');

  final AttachmentService attachmentService;
  final AttachmentTempStorage _tempStorage;
  final MethodChannel _platformChannel;

  /// Decrypts and opens an attachment in the native operating system.
  Future<({AttachmentOpenStatus status, String? errorMessage})> openAttachment(
    String attachmentId, {
    String? fallbackFileName,
  }) async {
    try {
      final resolution = await attachmentService.resolveAsset(attachmentId);
      if (!resolution.isAvailable || resolution.data == null) {
        return (
          status: AttachmentOpenStatus.missingOrUnavailable,
          errorMessage: resolution.errorMessage ?? 'Attachment unavailable',
        );
      }

      final entity = await attachmentService.database.getAttachment(attachmentId);
      final fileName = entity?.fileName ?? fallbackFileName ?? 'attachment_$attachmentId';
      final mimeType = entity?.mimeType ?? AttachmentTypeResolver.inferMimeType(fileName);

      // 1. Create temporary decrypted file
      final tempFile = await _tempStorage.createTemporaryDecryptedFile(
        attachmentId: attachmentId,
        rawFileName: fileName,
        plaintextBytes: resolution.data!,
      );

      // 2. Open via native platform mechanism
      final success = await _launchFile(tempFile, mimeType);
      if (success) {
        return (status: AttachmentOpenStatus.opened, errorMessage: null);
      } else {
        return (
          status: AttachmentOpenStatus.failed,
          errorMessage: 'No external application found to open this file',
        );
      }
    } catch (e) {
      debugPrint('Error opening attachment $attachmentId: $e');
      return (
        status: AttachmentOpenStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> _launchFile(File file, String mimeType) async {
    if (kIsWeb) return false;

    // 1. Try native platform channel (Android / custom OS handlers)
    try {
      final result = await _platformChannel.invokeMethod<bool>('openFile', {
        'filePath': file.path,
        'mimeType': mimeType,
      });
      if (result != null) return result;
    } catch (e) {
      debugPrint('openFile platform channel fallback: $e');
    }

    // 2. Try url_launcher Uri.file
    try {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Share sheet
    try {
      await Share.shareXFiles(
        [XFile(file.path, name: file.uri.pathSegments.last, mimeType: mimeType)],
      );
      return true;
    } catch (e) {
      debugPrint('Share fallback failed: $e');
      return false;
    }
  }
}
