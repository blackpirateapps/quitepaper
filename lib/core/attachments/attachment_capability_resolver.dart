import 'package:flutter/foundation.dart';
import 'attachment_models.dart';
import 'attachment_type_resolver.dart';
import 'text/attachment_text_detector.dart';

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

  /// Local in-viewer search
  search,

  /// Text selection and copy
  selectText,

  /// Create a new independent Note from attachment content
  createNote,

  /// Render Markdown document in rich preview
  renderMarkdown,

  /// Tabular data grid view (for CSV/TSV)
  tableView,

  /// Line numbers presentation
  lineNumbers,

  /// Word wrap toggle presentation
  wrapToggle,
}

/// Centralized resolver determining supported capabilities for attachments.
class AttachmentCapabilityResolver {
  const AttachmentCapabilityResolver._();

  /// Returns the set of supported capabilities for an attachment.
  static Set<AttachmentCapability> getCapabilities({
    required String mimeType,
    required String fileName,
    dynamic kind = AttachmentKind.file,
  }) {
    final effectiveKind = kind is AttachmentKind
        ? kind
        : (kind is String ? AttachmentKind.fromIdentifier(kind) : AttachmentKind.file);

    if (effectiveKind == AttachmentKind.image || AttachmentTypeResolver.isImageMime(mimeType)) {
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

    if (effectiveKind == AttachmentKind.document || AttachmentTypeResolver.isPdfMime(mimeType)) {
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
        AttachmentCapability.search,
        AttachmentCapability.selectText,
      };
    }

    // Check Text Attachment Formats
    final textFormat = AttachmentTextDetector.detectFormat(
      fileName: fileName,
      bytes: Uint8List(0),
      mimeType: mimeType,
    );

    if (AttachmentTextDetector.isTextFormat(textFormat)) {
      final baseCaps = <AttachmentCapability>{
        AttachmentCapability.storage,
        AttachmentCapability.openExternally,
        AttachmentCapability.share,
        AttachmentCapability.rename,
        AttachmentCapability.delete,
        AttachmentCapability.download,
        AttachmentCapability.preview,
        AttachmentCapability.search,
        AttachmentCapability.selectText,
        AttachmentCapability.createNote,
        AttachmentCapability.wrapToggle,
      };

      if (textFormat == TextAttachmentFormat.markdown) {
        baseCaps.add(AttachmentCapability.renderMarkdown);
      }

      if (textFormat == TextAttachmentFormat.csv || textFormat == TextAttachmentFormat.tsv) {
        baseCaps.add(AttachmentCapability.tableView);
      }

      if (AttachmentTextDetector.supportsLineNumbers(textFormat)) {
        baseCaps.add(AttachmentCapability.lineNumbers);
      }

      return baseCaps;
    }

    // Generic non-previewable binary files (ZIP, EXE, DOCX, XLSX, etc.)
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
    dynamic kind = AttachmentKind.file,
  }) {
    final caps = getCapabilities(
      mimeType: mimeType,
      fileName: fileName,
      kind: kind,
    );
    return caps.contains(capability);
  }
}
