import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

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

/// Sync payload representing scanned document metadata exchanged with the Vercel backend.
@immutable
class DocumentSyncPayload {
  const DocumentSyncPayload({
    required this.id,
    this.noteId,
    this.title = 'Scanned Document',
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
  });

  final String id;
  final String? noteId;
  final String title;
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

  Map<String, dynamic> toJson() => {
        'id': id,
        if (noteId != null) 'noteId': noteId,
        'title': title,
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
      };

  factory DocumentSyncPayload.fromJson(Map<String, dynamic> json) {
    return DocumentSyncPayload(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      title: json['title'] as String? ?? 'Scanned Document',
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
    );
  }

  factory DocumentSyncPayload.fromEntity(DocumentEntity entity) {
    return DocumentSyncPayload(
      id: entity.id,
      noteId: entity.noteId,
      title: entity.title,
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
    );
  }
}
