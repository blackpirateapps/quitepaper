import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/ocr/ocr_models.dart';

/// Supported individual note export formats.
enum ExportFormat {
  /// Canonical Markdown document (`.md`).
  markdown('md', 'Markdown', 'text/markdown'),

  /// Searchable vector PDF document (`.pdf`).
  pdf('pdf', 'PDF Document', 'application/pdf'),

  /// Standalone self-contained HTML5 document (`.html`).
  html('html', 'HTML Webpage', 'text/html'),

  /// Clean readable plain text document (`.txt`).
  plainText('txt', 'Plain Text', 'text/plain'),

  /// Microsoft Word OpenXML document (`.docx`).
  docx('docx', 'Microsoft Word', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),

  /// Full-fidelity Quiet Paper Note Package (`.qpnote`).
  qpnote('qpnote', 'Quiet Paper Package', 'application/vnd.quietpaper.note');

  const ExportFormat(this.extension, this.displayName, this.mimeType);

  final String extension;
  final String displayName;
  final String mimeType;

  static ExportFormat fromExtension(String? ext) {
    if (ext == null) return ExportFormat.markdown;
    final clean = ext.toLowerCase().replaceAll('.', '').trim();
    for (final format in ExportFormat.values) {
      if (format.extension == clean) return format;
    }
    return ExportFormat.markdown;
  }
}

/// Strategy for handling embedded image and document attachments in exported notes.
enum AttachmentExportStrategy {
  /// Do not include or reference attachments in the export.
  none('none', 'None'),

  /// Download and embed attachments locally (in package or relative directory).
  embedLocally('embed_locally', 'Embed Locally'),

  /// Preserve original remote Cloudinary/web URLs in document references.
  preserveRemoteUrls('preserve_remote_urls', 'Preserve Remote URLs');

  const AttachmentExportStrategy(this.identifier, this.displayName);
  final String identifier;
  final String displayName;

  static AttachmentExportStrategy fromIdentifier(String? id) {
    if (id == null) return AttachmentExportStrategy.embedLocally;
    for (final s in AttachmentExportStrategy.values) {
      if (s.identifier == id) return s;
    }
    return AttachmentExportStrategy.embedLocally;
  }
}

/// Strategy for including OCR recognized text in export.
enum OcrExportStrategy {
  /// Do not include OCR datasets.
  none('none', 'None'),

  /// Export OCR data as separate structured files (e.g. in `.qpnote`).
  separateFiles('separate_files', 'Separate Files'),

  /// Append OCR recognized text to the end of the document body.
  appendToDocument('append_to_document', 'Append to Document');

  const OcrExportStrategy(this.identifier, this.displayName);
  final String identifier;
  final String displayName;

  static OcrExportStrategy fromIdentifier(String? id) {
    if (id == null) return OcrExportStrategy.none;
    for (final s in OcrExportStrategy.values) {
      if (s.identifier == id) return s;
    }
    return OcrExportStrategy.none;
  }
}

/// Strategy for handling internal note links (`qp://note/<UUID>` or `[[Note Title]]`).
enum NoteLinkStrategy {
  /// Keep canonical `qp://note/<UUID>` URI scheme.
  preserveQuietPaperUri('preserve_quiet_paper_uri', 'Preserve Quiet Paper URI'),

  /// Format as standard clickable link if title is known.
  preserveAsLinks('preserve_as_links', 'Preserve as Links'),

  /// Rewrite internal links to relative files if matching target is available.
  rewriteToRelativeFiles('rewrite_to_relative_files', 'Rewrite to Relative Files'),

  /// Convert internal links to plain text title representation.
  plainTextRepresentation('plain_text_representation', 'Plain Text Representation');

  const NoteLinkStrategy(this.identifier, this.displayName);
  final String identifier;
  final String displayName;

  static NoteLinkStrategy fromIdentifier(String? id) {
    if (id == null) return NoteLinkStrategy.preserveQuietPaperUri;
    for (final s in NoteLinkStrategy.values) {
      if (s.identifier == id) return s;
    }
    return NoteLinkStrategy.preserveQuietPaperUri;
  }
}

/// Options specific to PDF document generation.
@immutable
class PdfExportOptions {
  const PdfExportOptions({
    this.includeMetadata = true,
    this.showTags = true,
    this.showDates = true,
    this.showBacklinks = false,
    this.includeAttachments = true,
    this.includeOcr = false,
    this.pageSize = 'A4',
  });

  final bool includeMetadata;
  final bool showTags;
  final bool showDates;
  final bool showBacklinks;
  final bool includeAttachments;
  final bool includeOcr;
  final String pageSize;

  PdfExportOptions copyWith({
    bool? includeMetadata,
    bool? showTags,
    bool? showDates,
    bool? showBacklinks,
    bool? includeAttachments,
    bool? includeOcr,
    String? pageSize,
  }) {
    return PdfExportOptions(
      includeMetadata: includeMetadata ?? this.includeMetadata,
      showTags: showTags ?? this.showTags,
      showDates: showDates ?? this.showDates,
      showBacklinks: showBacklinks ?? this.showBacklinks,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      includeOcr: includeOcr ?? this.includeOcr,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'includeMetadata': includeMetadata,
        'showTags': showTags,
        'showDates': showDates,
        'showBacklinks': showBacklinks,
        'includeAttachments': includeAttachments,
        'includeOcr': includeOcr,
        'pageSize': pageSize,
      };

  factory PdfExportOptions.fromJson(Map<String, dynamic> json) {
    return PdfExportOptions(
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      showTags: json['showTags'] as bool? ?? true,
      showDates: json['showDates'] as bool? ?? true,
      showBacklinks: json['showBacklinks'] as bool? ?? false,
      includeAttachments: json['includeAttachments'] as bool? ?? true,
      includeOcr: json['includeOcr'] as bool? ?? false,
      pageSize: json['pageSize'] as String? ?? 'A4',
    );
  }
}

/// Options specific to HTML document generation.
@immutable
class HtmlExportOptions {
  const HtmlExportOptions({
    this.includeMetadata = true,
    this.includeAttachments = true,
    this.includeOcr = false,
    this.embedImagesAsBase64 = true,
    this.darkMode = false,
  });

  final bool includeMetadata;
  final bool includeAttachments;
  final bool includeOcr;
  final bool embedImagesAsBase64;
  final bool darkMode;

  HtmlExportOptions copyWith({
    bool? includeMetadata,
    bool? includeAttachments,
    bool? includeOcr,
    bool? embedImagesAsBase64,
    bool? darkMode,
  }) {
    return HtmlExportOptions(
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      includeOcr: includeOcr ?? this.includeOcr,
      embedImagesAsBase64: embedImagesAsBase64 ?? this.embedImagesAsBase64,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'includeMetadata': includeMetadata,
        'includeAttachments': includeAttachments,
        'includeOcr': includeOcr,
        'embedImagesAsBase64': embedImagesAsBase64,
        'darkMode': darkMode,
      };

  factory HtmlExportOptions.fromJson(Map<String, dynamic> json) {
    return HtmlExportOptions(
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      includeAttachments: json['includeAttachments'] as bool? ?? true,
      includeOcr: json['includeOcr'] as bool? ?? false,
      embedImagesAsBase64: json['embedImagesAsBase64'] as bool? ?? true,
      darkMode: json['darkMode'] as bool? ?? false,
    );
  }
}

/// Options specific to DOCX generation.
@immutable
class DocxExportOptions {
  const DocxExportOptions({
    this.includeMetadata = true,
    this.includeAttachments = true,
    this.includeOcr = false,
  });

  final bool includeMetadata;
  final bool includeAttachments;
  final bool includeOcr;

  DocxExportOptions copyWith({
    bool? includeMetadata,
    bool? includeAttachments,
    bool? includeOcr,
  }) {
    return DocxExportOptions(
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      includeOcr: includeOcr ?? this.includeOcr,
    );
  }

  Map<String, dynamic> toJson() => {
        'includeMetadata': includeMetadata,
        'includeAttachments': includeAttachments,
        'includeOcr': includeOcr,
      };

  factory DocxExportOptions.fromJson(Map<String, dynamic> json) {
    return DocxExportOptions(
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      includeAttachments: json['includeAttachments'] as bool? ?? true,
      includeOcr: json['includeOcr'] as bool? ?? false,
    );
  }
}

/// Options specific to .qpnote package generation.
@immutable
class QpNoteExportOptions {
  const QpNoteExportOptions({
    this.includeMetadata = true,
    this.includeAttachments = true,
    this.includeOcr = true,
    this.preserveIds = true,
    this.preserveTrashState = true,
    this.isEncrypted = false,
    this.packagePassword,
  });

  final bool includeMetadata;
  final bool includeAttachments;
  final bool includeOcr;
  final bool preserveIds;
  final bool preserveTrashState;
  final bool isEncrypted;
  final String? packagePassword;

  QpNoteExportOptions copyWith({
    bool? includeMetadata,
    bool? includeAttachments,
    bool? includeOcr,
    bool? preserveIds,
    bool? preserveTrashState,
    bool? isEncrypted,
    String? packagePassword,
  }) {
    return QpNoteExportOptions(
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      includeOcr: includeOcr ?? this.includeOcr,
      preserveIds: preserveIds ?? this.preserveIds,
      preserveTrashState: preserveTrashState ?? this.preserveTrashState,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      packagePassword: packagePassword ?? this.packagePassword,
    );
  }

  Map<String, dynamic> toJson() => {
        'includeMetadata': includeMetadata,
        'includeAttachments': includeAttachments,
        'includeOcr': includeOcr,
        'preserveIds': preserveIds,
        'preserveTrashState': preserveTrashState,
        'isEncrypted': isEncrypted,
      };

  factory QpNoteExportOptions.fromJson(Map<String, dynamic> json) {
    return QpNoteExportOptions(
      includeMetadata: json['includeMetadata'] as bool? ?? true,
      includeAttachments: json['includeAttachments'] as bool? ?? true,
      includeOcr: json['includeOcr'] as bool? ?? true,
      preserveIds: json['preserveIds'] as bool? ?? true,
      preserveTrashState: json['preserveTrashState'] as bool? ?? true,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      packagePassword: json['packagePassword'] as String?,
    );
  }
}

/// Strongly typed request container specifying export parameters.
@immutable
class ExportRequest {
  const ExportRequest({
    required this.noteId,
    required this.format,
    this.includeMetadata = true,
    this.includeAttachments = true,
    this.attachmentStrategy = AttachmentExportStrategy.embedLocally,
    this.includeOcr = false,
    this.ocrStrategy = OcrExportStrategy.none,
    this.noteLinkStrategy = NoteLinkStrategy.preserveQuietPaperUri,
    this.includeInternalIds = true,
    this.pdfOptions = const PdfExportOptions(),
    this.htmlOptions = const HtmlExportOptions(),
    this.docxOptions = const DocxExportOptions(),
    this.packageOptions = const QpNoteExportOptions(),
    this.shareAfterExport = false,
    this.notePassword,
  });

  final String noteId;
  final ExportFormat format;
  final bool includeMetadata;
  final bool includeAttachments;
  final AttachmentExportStrategy attachmentStrategy;
  final bool includeOcr;
  final OcrExportStrategy ocrStrategy;
  final NoteLinkStrategy noteLinkStrategy;
  final bool includeInternalIds;
  final PdfExportOptions pdfOptions;
  final HtmlExportOptions htmlOptions;
  final DocxExportOptions docxOptions;
  final QpNoteExportOptions packageOptions;
  final bool shareAfterExport;
  final String? notePassword;

  /// Creates a default request tailored to a given format.
  factory ExportRequest.forFormat(
    String noteId,
    ExportFormat format, {
    String? notePassword,
    bool shareAfterExport = false,
  }) {
    switch (format) {
      case ExportFormat.markdown:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: false,
          includeAttachments: true,
          attachmentStrategy: AttachmentExportStrategy.embedLocally,
          includeOcr: false,
          noteLinkStrategy: NoteLinkStrategy.preserveQuietPaperUri,
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
      case ExportFormat.pdf:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: true,
          includeAttachments: true,
          attachmentStrategy: AttachmentExportStrategy.embedLocally,
          includeOcr: false,
          pdfOptions: const PdfExportOptions(
            showTags: true,
            showDates: true,
            showBacklinks: false,
            includeAttachments: true,
          ),
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
      case ExportFormat.html:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: true,
          includeAttachments: true,
          attachmentStrategy: AttachmentExportStrategy.embedLocally,
          includeOcr: false,
          htmlOptions: const HtmlExportOptions(
            includeMetadata: true,
            includeAttachments: true,
            embedImagesAsBase64: true,
          ),
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
      case ExportFormat.plainText:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: false,
          includeAttachments: false,
          includeOcr: false,
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
      case ExportFormat.docx:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: true,
          includeAttachments: true,
          attachmentStrategy: AttachmentExportStrategy.embedLocally,
          includeOcr: false,
          docxOptions: const DocxExportOptions(
            includeMetadata: true,
            includeAttachments: true,
          ),
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
      case ExportFormat.qpnote:
        return ExportRequest(
          noteId: noteId,
          format: format,
          includeMetadata: true,
          includeAttachments: true,
          attachmentStrategy: AttachmentExportStrategy.embedLocally,
          includeOcr: true,
          ocrStrategy: OcrExportStrategy.separateFiles,
          includeInternalIds: true,
          packageOptions: const QpNoteExportOptions(
            includeMetadata: true,
            includeAttachments: true,
            includeOcr: true,
            preserveIds: true,
            preserveTrashState: true,
          ),
          notePassword: notePassword,
          shareAfterExport: shareAfterExport,
        );
    }
  }

  ExportRequest copyWith({
    String? noteId,
    ExportFormat? format,
    bool? includeMetadata,
    bool? includeAttachments,
    AttachmentExportStrategy? attachmentStrategy,
    bool? includeOcr,
    OcrExportStrategy? ocrStrategy,
    NoteLinkStrategy? noteLinkStrategy,
    bool? includeInternalIds,
    PdfExportOptions? pdfOptions,
    HtmlExportOptions? htmlOptions,
    DocxExportOptions? docxOptions,
    QpNoteExportOptions? packageOptions,
    bool? shareAfterExport,
    String? notePassword,
  }) {
    return ExportRequest(
      noteId: noteId ?? this.noteId,
      format: format ?? this.format,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      includeAttachments: includeAttachments ?? this.includeAttachments,
      attachmentStrategy: attachmentStrategy ?? this.attachmentStrategy,
      includeOcr: includeOcr ?? this.includeOcr,
      ocrStrategy: ocrStrategy ?? this.ocrStrategy,
      noteLinkStrategy: noteLinkStrategy ?? this.noteLinkStrategy,
      includeInternalIds: includeInternalIds ?? this.includeInternalIds,
      pdfOptions: pdfOptions ?? this.pdfOptions,
      htmlOptions: htmlOptions ?? this.htmlOptions,
      docxOptions: docxOptions ?? this.docxOptions,
      packageOptions: packageOptions ?? this.packageOptions,
      shareAfterExport: shareAfterExport ?? this.shareAfterExport,
      notePassword: notePassword ?? this.notePassword,
    );
  }
}

/// Category of non-fatal export warning.
enum ExportWarningType {
  attachmentUnavailable,
  unsupportedMarkdownFeature,
  ocrUnavailable,
  syntaxHighlightingFallback,
  metadataOmitted,
  partialContent,
}

/// Structured non-fatal warning generated during export.
@immutable
class ExportWarning {
  const ExportWarning({
    required this.type,
    required this.message,
    this.details,
  });

  final ExportWarningType type;
  final String message;
  final String? details;

  @override
  String toString() => '$type: $message${details != null ? " ($details)" : ""}';
}

/// Strongly typed container returned upon export completion.
@immutable
class ExportResult {
  const ExportResult({
    required this.file,
    required this.format,
    required this.filename,
    required this.byteSize,
    required this.mimeType,
    required this.duration,
    this.warnings = const [],
    this.isShared = false,
    this.isSaved = false,
  });

  final File file;
  final ExportFormat format;
  final String filename;
  final int byteSize;
  final String mimeType;
  final Duration duration;
  final List<ExportWarning> warnings;
  final bool isShared;
  final bool isSaved;

  bool get hasWarnings => warnings.isNotEmpty;

  ExportResult copyWith({
    File? file,
    ExportFormat? format,
    String? filename,
    int? byteSize,
    String? mimeType,
    Duration? duration,
    List<ExportWarning>? warnings,
    bool? isShared,
    bool? isSaved,
  }) {
    return ExportResult(
      file: file ?? this.file,
      format: format ?? this.format,
      filename: filename ?? this.filename,
      byteSize: byteSize ?? this.byteSize,
      mimeType: mimeType ?? this.mimeType,
      duration: duration ?? this.duration,
      warnings: warnings ?? this.warnings,
      isShared: isShared ?? this.isShared,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

/// Immutable snapshot representing the complete logical state of a note and its resources.
@immutable
class NoteExportSnapshot {
  const NoteExportSnapshot({
    required this.noteId,
    required this.title,
    required this.markdown,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.deletedAt,
    this.tags = const [],
    this.isPasswordProtected = false,
    this.passwordHint,
    this.attachments = const [],
    this.documents = const [],
    this.ocrData = const [],
  });

  final String noteId;
  final String title;
  final String markdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final DateTime? deletedAt;
  final List<String> tags;
  final bool isPasswordProtected;
  final String? passwordHint;
  final List<ExportAttachmentItem> attachments;
  final List<ExportDocumentItem> documents;
  final List<ExportOcrItem> ocrData;

  String get effectiveTitle => title.trim().isNotEmpty ? title.trim() : 'Untitled';

  NoteExportSnapshot copyWith({
    String? noteId,
    String? title,
    String? markdown,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isArchived,
    bool? isTrashed,
    DateTime? deletedAt,
    List<String>? tags,
    bool? isPasswordProtected,
    String? passwordHint,
    List<ExportAttachmentItem>? attachments,
    List<ExportDocumentItem>? documents,
    List<ExportOcrItem>? ocrData,
  }) {
    return NoteExportSnapshot(
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      deletedAt: deletedAt ?? this.deletedAt,
      tags: tags ?? this.tags,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      passwordHint: passwordHint ?? this.passwordHint,
      attachments: attachments ?? this.attachments,
      documents: documents ?? this.documents,
      ocrData: ocrData ?? this.ocrData,
    );
  }
}

/// Resolved binary attachment item inside an export snapshot.
@immutable
class ExportAttachmentItem {
  const ExportAttachmentItem({
    required this.id,
    this.noteId,
    required this.originalFilename,
    required this.mimeType,
    required this.relativePath,
    required this.byteSize,
    required this.createdAt,
    required this.sha256,
    this.width,
    this.height,
    this.variant = 'original',
    this.bytes,
    this.cloudUrl,
  });

  final String id;
  final String? noteId;
  final String originalFilename;
  final String mimeType;
  final String relativePath;
  final int byteSize;
  final DateTime createdAt;
  final String sha256;
  final int? width;
  final int? height;
  final String variant;
  final Uint8List? bytes;
  final String? cloudUrl;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

/// Resolved document item inside an export snapshot.
@immutable
class ExportDocumentItem {
  const ExportDocumentItem({
    required this.id,
    this.noteId,
    required this.title,
    required this.mimeType,
    required this.relativePath,
    required this.byteSize,
    required this.pageCount,
    required this.createdAt,
    required this.sha256,
    this.source = 'scanner',
    this.bytes,
    this.cloudUrl,
  });

  final String id;
  final String? noteId;
  final String title;
  final String mimeType;
  final String relativePath;
  final int byteSize;
  final int pageCount;
  final DateTime createdAt;
  final String sha256;
  final String source;
  final Uint8List? bytes;
  final String? cloudUrl;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

/// Resolved OCR dataset associated with a document or attachment.
@immutable
class ExportOcrItem {
  const ExportOcrItem({
    required this.resourceId,
    required this.resourceType,
    required this.document,
    this.relativePath = '',
  });

  final String resourceId;
  final String resourceType; // 'document' or 'asset'
  final OcrDocument document;
  final String relativePath;
}

/// Lifecycle phases of the export workflow.
enum ExportPhase {
  preparingNote('Preparing note...'),
  resolvingAttachments('Resolving attachments...'),
  resolvingOcr('Resolving OCR text...'),
  renderingDocument('Rendering document...'),
  compressingPackage('Packaging files...'),
  saving('Saving file...'),
  sharing('Opening share sheet...'),
  complete('Export complete!'),
  failed('Export failed');

  const ExportPhase(this.displayMessage);
  final String displayMessage;
}

/// Reactive state describing export progress.
@immutable
class ExportProgressState {
  const ExportProgressState({
    required this.phase,
    this.progress = 0.0,
    this.message,
    this.currentResource,
    this.totalResources,
  });

  final ExportPhase phase;
  final double progress;
  final String? message;
  final int? currentResource;
  final int? totalResources;

  String get effectiveMessage => message ?? phase.displayMessage;

  static const initial = ExportProgressState(phase: ExportPhase.preparingNote);
}
