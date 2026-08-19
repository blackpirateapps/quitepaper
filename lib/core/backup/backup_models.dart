import 'package:flutter/foundation.dart';
import '../crypto/crypto_service.dart';

enum RestoreStrategy {
  merge,
  keepBoth,
  replace,
}

@immutable
class BackupNote {
  const BackupNote({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.isPinned,
    required this.isArchived,
    required this.isTrashed,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'isPinned': isPinned,
        'isArchived': isArchived,
        'isTrashed': isTrashed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory BackupNote.fromJson(Map<String, dynamic> json) {
    return BackupNote(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      isTrashed: json['isTrashed'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
    );
  }
}

@immutable
class BackupAttachment {
  const BackupAttachment({
    required this.id,
    this.noteId,
    required this.createdAt,
    required this.updatedAt,
    this.mimeType = 'image/png',
    this.byteSize = 0,
    this.width,
    this.height,
    this.sha256 = '',
    this.encryptionKeyVersion = 1,
    this.encryptedPayloadBase64,
  });

  final String id;
  final String? noteId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final String sha256;
  final int encryptionKeyVersion;
  final String? encryptedPayloadBase64;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (noteId != null) 'noteId': noteId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mimeType': mimeType,
        'byteSize': byteSize,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'sha256': sha256,
        'encryptionKeyVersion': encryptionKeyVersion,
        if (encryptedPayloadBase64 != null)
          'encryptedPayloadBase64': encryptedPayloadBase64,
      };

  factory BackupAttachment.fromJson(Map<String, dynamic> json) {
    return BackupAttachment(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      mimeType: json['mimeType'] as String? ?? 'image/png',
      byteSize: json['byteSize'] as int? ?? 0,
      width: json['width'] as int?,
      height: json['height'] as int?,
      sha256: json['sha256'] as String? ?? '',
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      encryptedPayloadBase64: json['encryptedPayloadBase64'] as String?,
    );
  }
}

@immutable
class BackupManifest {
  const BackupManifest({
    required this.format,
    required this.version,
    required this.appVersion,
    required this.createdAt,
    required this.isEncrypted,
    required this.totalNotes,
    required this.activeNotes,
    required this.archivedNotes,
    required this.trashedNotes,
    required this.pinnedNotes,
    required this.totalTags,
    this.totalAttachments = 0,
  });

  final String format;
  final int version;
  final String appVersion;
  final DateTime createdAt;
  final bool isEncrypted;
  final int totalNotes;
  final int activeNotes;
  final int archivedNotes;
  final int trashedNotes;
  final int pinnedNotes;
  final int totalTags;
  final int totalAttachments;

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'appVersion': appVersion,
        'createdAt': createdAt.toIso8601String(),
        'isEncrypted': isEncrypted,
        'metadata': {
          'totalNotes': totalNotes,
          'activeNotes': activeNotes,
          'archivedNotes': archivedNotes,
          'trashedNotes': trashedNotes,
          'pinnedNotes': pinnedNotes,
          'totalTags': totalTags,
          'totalAttachments': totalAttachments,
        },
      };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    return BackupManifest(
      format: json['format'] as String? ?? 'quietpaper:backup:v1',
      version: json['version'] as int? ?? 1,
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      totalNotes: meta['totalNotes'] as int? ?? 0,
      activeNotes: meta['activeNotes'] as int? ?? 0,
      archivedNotes: meta['archivedNotes'] as int? ?? 0,
      trashedNotes: meta['trashedNotes'] as int? ?? 0,
      pinnedNotes: meta['pinnedNotes'] as int? ?? 0,
      totalTags: meta['totalTags'] as int? ?? 0,
      totalAttachments: meta['totalAttachments'] as int? ?? 0,
    );
  }
}

@immutable
class BackupPayload {
  const BackupPayload({
    required this.manifest,
    required this.notes,
    required this.tags,
    this.attachments = const [],
  });

  final BackupManifest manifest;
  final List<BackupNote> notes;
  final List<String> tags;
  final List<BackupAttachment> attachments;

  Map<String, dynamic> toJson() => {
        ...manifest.toJson(),
        'tags': tags,
        'notes': notes.map((n) => n.toJson()).toList(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final manifest = BackupManifest.fromJson(json);
    final rawNotes = json['notes'] as List? ?? [];
    final rawTags = json['tags'] as List? ?? [];
    final rawAttachments = json['attachments'] as List? ?? [];

    final notes = rawNotes
        .whereType<Map>()
        .map((e) => BackupNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final tags = rawTags.map((e) => e.toString()).toList();

    final attachments = rawAttachments
        .whereType<Map>()
        .map((e) => BackupAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return BackupPayload(
      manifest: manifest,
      notes: notes,
      tags: tags,
      attachments: attachments,
    );
  }
}

@immutable
class EncryptedBackupEnvelope {
  const EncryptedBackupEnvelope({
    this.format = 'quietpaper:encrypted-backup:v1',
    this.version = 1,
    this.kdfAlgorithm = 'argon2id',
    required this.kdfSalt,
    required this.kdfParameters,
    required this.nonce,
    required this.ciphertext,
    this.manifestSummary,
  });

  final String format;
  final int version;
  final String kdfAlgorithm;
  final String kdfSalt;
  final KdfParameters kdfParameters;
  final String nonce;
  final String ciphertext;
  final BackupManifest? manifestSummary;

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'kdfAlgorithm': kdfAlgorithm,
        'kdfSalt': kdfSalt,
        'kdfParameters': kdfParameters.toJson(),
        'nonce': nonce,
        'ciphertext': ciphertext,
        if (manifestSummary != null)
          'manifestSummary': manifestSummary!.toJson(),
      };

  factory EncryptedBackupEnvelope.fromJson(Map<String, dynamic> json) {
    final rawManifest = json['manifestSummary'] as Map<String, dynamic>?;
    return EncryptedBackupEnvelope(
      format: json['format'] as String? ?? 'quietpaper:encrypted-backup:v1',
      version: json['version'] as int? ?? 1,
      kdfAlgorithm: json['kdfAlgorithm'] as String? ?? 'argon2id',
      kdfSalt: json['kdfSalt'] as String? ?? '',
      kdfParameters: json['kdfParameters'] != null
          ? KdfParameters.fromJson(json['kdfParameters'] as Map<String, dynamic>)
          : KdfParameters.standard,
      nonce: json['nonce'] as String? ?? '',
      ciphertext: json['ciphertext'] as String? ?? '',
      manifestSummary:
          rawManifest != null ? BackupManifest.fromJson(rawManifest) : null,
    );
  }
}

@immutable
class BackupValidationResult {
  const BackupValidationResult({
    required this.isValid,
    required this.isEncrypted,
    this.manifest,
    this.payload,
    this.errorMessage,
  });

  final bool isValid;
  final bool isEncrypted;
  final BackupManifest? manifest;
  final BackupPayload? payload;
  final String? errorMessage;
}

@immutable
class RestoreResult {
  const RestoreResult({
    required this.totalRestored,
    required this.totalUpdated,
    required this.totalSkipped,
    required this.totalConflicts,
    required this.totalTagsCreated,
  });

  final int totalRestored;
  final int totalUpdated;
  final int totalSkipped;
  final int totalConflicts;
  final int totalTagsCreated;
}

@immutable
class AutoBackupConfig {
  const AutoBackupConfig({
    this.enabled = false,
    this.folderPath,
    this.retentionCount = 5,
    this.lastBackupAt,
    this.hasPassword = false,
  });

  final bool enabled;
  final String? folderPath;
  final int retentionCount;
  final DateTime? lastBackupAt;
  final bool hasPassword;

  AutoBackupConfig copyWith({
    bool? enabled,
    String? folderPath,
    int? retentionCount,
    DateTime? lastBackupAt,
    bool? hasPassword,
  }) {
    return AutoBackupConfig(
      enabled: enabled ?? this.enabled,
      folderPath: folderPath ?? this.folderPath,
      retentionCount: retentionCount ?? this.retentionCount,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }
}
