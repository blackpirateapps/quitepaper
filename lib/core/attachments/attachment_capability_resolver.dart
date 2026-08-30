import 'attachment_models.dart';
import 'attachment_type_resolver.dart';

/// Capabilities supported by Quiet Paper attachments.
enum AttachmentCapability {
  /// Local encrypted persistence and retrieval
  storage,

  /// Handoff to external OS application via native intent/open
  openExternally,

  /// Native OS share sheet export
  share,

  /// User-facing filename metadata mutation without byte altering
  rename,

  /// Soft or permanent deletion from note/account
  delete,

  /// Save decrypted copy to phone storage / Downloads / SAF
  download,

  /// Text recognition / OCR indexing
  ocr,

  /// In-app rich preview rendering
  preview,

  /// First page or visual thumbnail rendering
  thumbnail,
}

/// Centralized resolver determining supported capabilities for attachments.
class AttachmentCapabilityResolver {
  const AttachmentCapabilityResolver._();

  /// Returns the set of supported capabilities for an attachment.
  static Set<AttachmentCapability> getCapabilities({
    required String mimeType,
    required String fileName,
    AttachmentKind kind = AttachmentKind.file,
  }) {
    if (kind == AttachmentKind.image || AttachmentTypeResolver.isImageMime(mimeType)) {
      return {
        AttachmentCapability.storage,
        AttachmentCapability.openExternally,
        AttachmentCapability.share,
        AttachmentCapability.rename,
        AttachmentCapability.delete,
        AttachmentCapability.download,
        AttachmentCapability.ocr,
        AttachmentCapability.preview,
        AttachmentCapability.thumbnail,
      };
    }

    if (kind == AttachmentKind.document || AttachmentTypeResolver.isPdfMime(mimeType)) {
      return {
        AttachmentCapability.storage,
        AttachmentCapability.openExternally,
        AttachmentCapability.share,
        AttachmentCapability.rename,
        AttachmentCapability.delete,
        AttachmentCapability.download,
        AttachmentCapability.ocr,
        AttachmentCapability.preview,
        AttachmentCapability.thumbnail,
      };
    }

    // Generic files (DOCX, XLSX, ZIP, code, audio, video, binary, etc.)
    return {
      AttachmentCapability.storage,
      AttachmentCapability.openExternally,
      AttachmentCapability.share,
      AttachmentCapability.rename,
      AttachmentCapability.delete,
      AttachmentCapability.download,
    };
  }

  /// Checks whether a specific capability is supported for an attachment.
  static bool supports({
    required AttachmentCapability capability,
    required String mimeType,
    required String fileName,
    AttachmentKind kind = AttachmentKind.file,
  }) {
    final caps = getCapabilities(
      mimeType: mimeType,
      fileName: fileName,
      kind: kind,
    );
    return caps.contains(capability);
  }
}
