import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// Method used to create the document resource.
enum DocumentSource {
  /// Captured using document camera scanner and compiled locally to PDF.
  scanner('scanner'),

  /// Imported from an existing local PDF file.
  importedPdf('imported_pdf'),

  /// Captured from a clipped web page preserving original HTML & CSS styles.
  webSnapshot('web_snapshot');

  const DocumentSource(this.identifier);
  final String identifier;

  static DocumentSource fromIdentifier(String? id) {
    if (id == null) return DocumentSource.scanner;
    for (final src in DocumentSource.values) {
      if (src.identifier == id || src.name == id) return src;
    }
    return DocumentSource.scanner;
  }
}

/// State of on-device OCR / text-extraction processing for a document.
enum OcrProcessingState {
  /// OCR has not been requested or started.
  notRequested('not_requested'),

  /// Scheduled in the asynchronous processing queue.
  queued('queued'),

  /// Actively processing text layer extraction / on-device OCR.
  processing('processing'),

  /// Structured OCR and searchable text are available.
  available('available'),

  /// Processing failed.
  failed('failed');

  const OcrProcessingState(this.identifier);
  final String identifier;

  static OcrProcessingState fromIdentifier(String? id) {
    if (id == null) return OcrProcessingState.notRequested;
    for (final state in OcrProcessingState.values) {
      if (state.identifier == id || state.name == id) return state;
    }
    return OcrProcessingState.notRequested;
  }

  bool get isProcessing => this == OcrProcessingState.processing || this == OcrProcessingState.queued;
  bool get isAvailable => this == OcrProcessingState.available;
  bool get isFailed => this == OcrProcessingState.failed;
}

/// State of a scanned document's cloud transfer lifecycle.
enum DocumentUploadState {
  /// Created and saved locally; not yet uploaded to cloud.
  localOnly('local_only'),

  /// Scheduled for cloud upload authorization and transfer.
  uploadPending('upload_pending'),

  /// Uploading encrypted PDF bytes directly to Cloudinary.
  uploading('uploading'),

  /// Direct upload to Cloudinary completed, awaiting backend metadata confirmation.
  uploaded('uploaded'),

  /// Upload attempt failed and pending retry.
  failed('failed'),

  /// Uploaded and metadata confirmed with backend sync control plane.
  synced('synced');

  const DocumentUploadState(this.identifier);
  final String identifier;

  static DocumentUploadState fromIdentifier(String? id) {
    if (id == null) return DocumentUploadState.localOnly;
    for (final state in DocumentUploadState.values) {
      if (state.identifier == id) return state;
    }
    return DocumentUploadState.localOnly;
  }
}

/// Sync payload representing scanned/imported document metadata exchanged with the Vercel backend.
@immutable
class DocumentSyncPayload {
  const DocumentSyncPayload({
    required this.id,
    this.noteId,
    this.title = 'Scanned Document',
    this.source = DocumentSource.scanner,
    required this.createdAt,
    required this.updatedAt,
    this.mimeType = 'application/pdf',
    this.byteSize = 0,
    this.pageCount = 1,
    this.sha256 = '',
    this.encryptionKeyVersion = 1,
    this.serverRevision = 0,
    this.isDeleted = false,
    this.deletedAt,
    this.cloudPublicId,
    this.cloudUrl,
    this.ocrState = OcrProcessingState.notRequested,
    this.ocrLanguage = 'en',
  });

  final String id;
  final String? noteId;
  final String title;
  final DocumentSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String mimeType;
  final int byteSize;
  final int pageCount;
  final String sha256;
  final int encryptionKeyVersion;
  final int serverRevision;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? cloudPublicId;
  final String? cloudUrl;
  final OcrProcessingState ocrState;
  final String ocrLanguage;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (noteId != null) 'noteId': noteId,
        'title': title,
        'source': source.identifier,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mimeType': mimeType,
        'byteSize': byteSize,
        'pageCount': pageCount,
        'sha256': sha256,
        'encryptionKeyVersion': encryptionKeyVersion,
        'serverRevision': serverRevision,
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (cloudPublicId != null) 'cloudPublicId': cloudPublicId,
        if (cloudUrl != null) 'cloudUrl': cloudUrl,
        'ocrState': ocrState.identifier,
        'ocrLanguage': ocrLanguage,
      };

  factory DocumentSyncPayload.fromJson(Map<String, dynamic> json) {
    return DocumentSyncPayload(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      title: json['title'] as String? ?? 'Scanned Document',
      source: DocumentSource.fromIdentifier(json['source'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      mimeType: json['mimeType'] as String? ?? 'application/pdf',
      byteSize: json['byteSize'] as int? ?? 0,
      pageCount: json['pageCount'] as int? ?? 1,
      sha256: json['sha256'] as String? ?? '',
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      serverRevision: json['serverRevision'] as int? ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
      cloudPublicId: json['cloudPublicId'] as String?,
      cloudUrl: json['cloudUrl'] as String?,
      ocrState: OcrProcessingState.fromIdentifier(json['ocrState'] as String?),
      ocrLanguage: json['ocrLanguage'] as String? ?? 'en',
    );
  }

  factory DocumentSyncPayload.fromEntity(DocumentEntity entity) {
    return DocumentSyncPayload(
      id: entity.id,
      noteId: entity.noteId,
      title: entity.title,
      source: DocumentSource.fromIdentifier(entity.source),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      mimeType: entity.mimeType,
      byteSize: entity.byteSize,
      pageCount: entity.pageCount,
      sha256: entity.sha256,
      encryptionKeyVersion: entity.encryptionKeyVersion,
      serverRevision: entity.serverRevision,
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt,
      cloudPublicId: entity.cloudPublicId,
      cloudUrl: entity.cloudUrl,
      ocrState: OcrProcessingState.fromIdentifier(entity.ocrState),
      ocrLanguage: entity.ocrLanguage,
    );
  }
}
