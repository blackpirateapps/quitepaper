import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// State of an attachment's cloud transfer lifecycle.
enum AttachmentUploadState {
  /// Created and saved locally; not yet uploaded to cloud.
  localOnly('local_only'),

  /// Scheduled for cloud upload authorization and transfer.
  uploadPending('upload_pending'),

  /// Uploading encrypted bytes directly to Cloudinary.
  uploading('uploading'),

  /// Direct upload to Cloudinary completed, awaiting backend metadata confirmation.
  uploaded('uploaded'),

  /// Upload attempt failed and pending retry.
  failed('failed'),

  /// Uploaded and metadata confirmed with backend sync control plane.
  synced('synced');

  const AttachmentUploadState(this.identifier);
  final String identifier;

  static AttachmentUploadState fromIdentifier(String? id) {
    if (id == null) return AttachmentUploadState.localOnly;
    for (final state in AttachmentUploadState.values) {
      if (state.identifier == id) return state;
    }
    return AttachmentUploadState.localOnly;
  }
}

/// Image variant representations supported by Quiet Paper.
enum AttachmentVariantType {
  original('original'),
  preview('preview'),
  thumbnail('thumbnail');

  const AttachmentVariantType(this.identifier);
  final String identifier;

  static AttachmentVariantType fromIdentifier(String? id) {
    if (id == null) return AttachmentVariantType.original;
    for (final v in AttachmentVariantType.values) {
      if (v.identifier == id) return v;
    }
    return AttachmentVariantType.original;
  }
}

/// Cloudinary upload authorization parameters provided by the Vercel backend control plane.
@immutable
class CloudinaryUploadAuth {
  const CloudinaryUploadAuth({
    required this.uploadUrl,
    required this.cloudName,
    required this.apiKey,
    required this.signature,
    required this.timestamp,
    required this.publicId,
    this.folder,
  });

  final String uploadUrl;
  final String cloudName;
  final String apiKey;
  final String signature;
  final int timestamp;
  final String publicId;
  final String? folder;

  Map<String, dynamic> toJson() => {
        'uploadUrl': uploadUrl,
        'cloudName': cloudName,
        'apiKey': apiKey,
        'signature': signature,
        'timestamp': timestamp,
        'publicId': publicId,
        if (folder != null) 'folder': folder,
      };

  factory CloudinaryUploadAuth.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadAuth(
      uploadUrl: json['uploadUrl'] as String? ??
          'https://api.cloudinary.com/v1_1/${json['cloudName']}/raw/upload',
      cloudName: json['cloudName'] as String,
      apiKey: json['apiKey'] as String,
      signature: json['signature'] as String,
      timestamp: json['timestamp'] as int,
      publicId: json['publicId'] as String,
      folder: json['folder'] as String?,
    );
  }
}

/// Successful direct upload result returned by Cloudinary.
@immutable
class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.byteSize,
    this.format,
    this.resourceType = 'raw',
  });

  final String publicId;
  final String secureUrl;
  final int byteSize;
  final String? format;
  final String resourceType;

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      publicId: json['public_id'] as String,
      secureUrl: json['secure_url'] as String,
      byteSize: json['bytes'] as int? ?? 0,
      format: json['format'] as String?,
      resourceType: json['resource_type'] as String? ?? 'raw',
    );
  }
}

/// Typed attachment classification kind.
enum AttachmentKind {
  /// Visual image asset
  image('image'),

  /// Scanned document / PDF asset
  document('document'),

  /// Generic arbitrary file asset (e.g. DOCX, XLSX, ZIP, code, audio, video, binary)
  file('file');

  const AttachmentKind(this.identifier);
  final String identifier;

  static AttachmentKind fromIdentifier(String? id) {
    if (id == null) return AttachmentKind.image;
    for (final k in AttachmentKind.values) {
      if (k.identifier == id) return k;
    }
    return AttachmentKind.file;
  }
}

/// Sync payload representing attachment metadata exchanged with the Vercel backend.
@immutable
class AttachmentSyncPayload {
  const AttachmentSyncPayload({
    required this.id,
    this.noteId,
    this.fileName = 'attachment',
    this.kind = 'image',
    required this.createdAt,
    required this.updatedAt,
    this.mimeType = 'image/png',
    this.byteSize = 0,
    this.width,
    this.height,
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
  final String fileName;
  final String kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
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
        'fileName': fileName,
        'kind': kind,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mimeType': mimeType,
        'byteSize': byteSize,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'sha256': sha256,
        'encryptionKeyVersion': encryptionKeyVersion,
        'serverRevision': serverRevision,
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (cloudPublicId != null) 'cloudPublicId': cloudPublicId,
        if (cloudUrl != null) 'cloudUrl': cloudUrl,
      };

  factory AttachmentSyncPayload.fromJson(Map<String, dynamic> json) {
    return AttachmentSyncPayload(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      fileName: json['fileName'] as String? ?? json['filename'] as String? ?? 'attachment',
      kind: json['kind'] as String? ?? 'image',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      mimeType: json['mimeType'] as String? ?? 'image/png',
      byteSize: json['byteSize'] as int? ?? 0,
      width: json['width'] as int?,
      height: json['height'] as int?,
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

  factory AttachmentSyncPayload.fromEntity(AttachmentEntity entity) {
    return AttachmentSyncPayload(
      id: entity.id,
      noteId: entity.noteId,
      fileName: entity.fileName,
      kind: entity.kind,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      mimeType: entity.mimeType,
      byteSize: entity.byteSize,
      width: entity.width,
      height: entity.height,
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
