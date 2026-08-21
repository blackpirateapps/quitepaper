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
class BackupAttachmentOcrPage {
  const BackupAttachmentOcrPage({
    required this.attachmentId,
    required this.pageNumber,
    required this.encryptedPayload,
    this.ocrSchemaVersion = 1,
    this.ocrEngine = 'quietpaper_ocr_v1',
    this.ocrEngineVersion = '1.0.0',
    this.language = 'en',
    required this.processedAt,
  });

  final String attachmentId;
  final int pageNumber;
  final String encryptedPayload;
  final int ocrSchemaVersion;
  final String ocrEngine;
  final String ocrEngineVersion;
  final String language;
  final DateTime processedAt;

  Map<String, dynamic> toJson() => {
        'attachmentId': attachmentId,
        'pageNumber': pageNumber,
        'encryptedPayload': encryptedPayload,
        'ocrSchemaVersion': ocrSchemaVersion,
        'ocrEngine': ocrEngine,
        'ocrEngineVersion': ocrEngineVersion,
        'language': language,
        'processedAt': processedAt.toIso8601String(),
      };

  factory BackupAttachmentOcrPage.fromJson(Map<String, dynamic> json) {
    return BackupAttachmentOcrPage(
      attachmentId: json['attachmentId'] as String? ?? '',
      pageNumber: json['pageNumber'] as int? ?? 1,
      encryptedPayload: json['encryptedPayload'] as String? ?? '',
      ocrSchemaVersion: json['ocrSchemaVersion'] as int? ?? 1,
      ocrEngine: json['ocrEngine'] as String? ?? 'quietpaper_ocr_v1',
      ocrEngineVersion: json['ocrEngineVersion'] as String? ?? '1.0.0',
      language: json['language'] as String? ?? 'en',
      processedAt: DateTime.tryParse(json['processedAt'] as String? ?? '') ??
          DateTime.now(),
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
    this.ocrState = 'not_requested',
    this.ocrLanguage = 'en',
    this.ocrPages = const [],
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
  final String ocrState;
  final String ocrLanguage;
  final List<BackupAttachmentOcrPage> ocrPages;

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
        'ocrState': ocrState,
        'ocrLanguage': ocrLanguage,
        if (ocrPages.isNotEmpty)
          'ocrPages': ocrPages.map((p) => p.toJson()).toList(),
      };

  factory BackupAttachment.fromJson(Map<String, dynamic> json) {
    final rawOcrPages = json['ocrPages'] as List? ?? [];
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
      ocrState: json['ocrState'] as String? ?? 'not_requested',
      ocrLanguage: json['ocrLanguage'] as String? ?? 'en',
      ocrPages: rawOcrPages
          .whereType<Map>()
          .map((p) => BackupAttachmentOcrPage.fromJson(
              Map<String, dynamic>.from(p)))
          .toList(),
    );
  }
}

@immutable
class BackupDocumentOcrPage {
  const BackupDocumentOcrPage({
    required this.documentId,
    required this.pageNumber,
    required this.encryptedPayload,
    this.ocrSchemaVersion = 1,
    this.ocrEngine = 'quietpaper_ocr_v1',
    this.ocrEngineVersion = '1.0.0',
    this.language = 'en',
    required this.processedAt,
  });

  final String documentId;
  final int pageNumber;
  final String encryptedPayload;
  final int ocrSchemaVersion;
  final String ocrEngine;
  final String ocrEngineVersion;
  final String language;
  final DateTime processedAt;

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'pageNumber': pageNumber,
        'encryptedPayload': encryptedPayload,
        'ocrSchemaVersion': ocrSchemaVersion,
        'ocrEngine': ocrEngine,
        'ocrEngineVersion': ocrEngineVersion,
        'language': language,
        'processedAt': processedAt.toIso8601String(),
      };

  factory BackupDocumentOcrPage.fromJson(Map<String, dynamic> json) {
    return BackupDocumentOcrPage(
      documentId: json['documentId'] as String? ?? '',
      pageNumber: json['pageNumber'] as int? ?? 1,
      encryptedPayload: json['encryptedPayload'] as String? ?? '',
      ocrSchemaVersion: json['ocrSchemaVersion'] as int? ?? 1,
      ocrEngine: json['ocrEngine'] as String? ?? 'quietpaper_ocr_v1',
      ocrEngineVersion: json['ocrEngineVersion'] as String? ?? '1.0.0',
      language: json['language'] as String? ?? 'en',
      processedAt: DateTime.tryParse(json['processedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

@immutable
class BackupDocument {
  const BackupDocument({
    required this.id,
    this.noteId,
    this.title = 'Scanned Document',
    this.source = 'scanner',
    required this.createdAt,
    required this.updatedAt,
    this.mimeType = 'application/pdf',
    this.byteSize = 0,
    this.pageCount = 1,
    this.sha256 = '',
    this.encryptionKeyVersion = 1,
    this.encryptedPayloadBase64,
    this.ocrState = 'not_requested',
    this.ocrLanguage = 'en',
    this.ocrPages = const [],
  });

  final String id;
  final String? noteId;
  final String title;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String mimeType;
  final int byteSize;
  final int pageCount;
  final String sha256;
  final int encryptionKeyVersion;
  final String? encryptedPayloadBase64;
  final String ocrState;
  final String ocrLanguage;
  final List<BackupDocumentOcrPage> ocrPages;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (noteId != null) 'noteId': noteId,
        'title': title,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'mimeType': mimeType,
        'byteSize': byteSize,
        'pageCount': pageCount,
        'sha256': sha256,
        'encryptionKeyVersion': encryptionKeyVersion,
        if (encryptedPayloadBase64 != null)
          'encryptedPayloadBase64': encryptedPayloadBase64,
        'ocrState': ocrState,
        'ocrLanguage': ocrLanguage,
        if (ocrPages.isNotEmpty)
          'ocrPages': ocrPages.map((p) => p.toJson()).toList(),
      };

  factory BackupDocument.fromJson(Map<String, dynamic> json) {
    final rawOcrPages = json['ocrPages'] as List? ?? [];
    return BackupDocument(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      title: json['title'] as String? ?? 'Scanned Document',
      source: json['source'] as String? ?? 'scanner',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      mimeType: json['mimeType'] as String? ?? 'application/pdf',
      byteSize: json['byteSize'] as int? ?? 0,
      pageCount: json['pageCount'] as int? ?? 1,
      sha256: json['sha256'] as String? ?? '',
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      encryptedPayloadBase64: json['encryptedPayloadBase64'] as String?,
      ocrState: json['ocrState'] as String? ?? 'not_requested',
      ocrLanguage: json['ocrLanguage'] as String? ?? 'en',
      ocrPages: rawOcrPages
          .whereType<Map>()
          .map((p) => BackupDocumentOcrPage.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
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
    this.totalDocuments = 0,
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
  final int totalDocuments;

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
          'totalDocuments': totalDocuments,
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
      totalDocuments: meta['totalDocuments'] as int? ?? 0,
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
    this.documents = const [],
  });

  final BackupManifest manifest;
  final List<BackupNote> notes;
  final List<String> tags;
  final List<BackupAttachment> attachments;
  final List<BackupDocument> documents;

  Map<String, dynamic> toJson() => {
        ...manifest.toJson(),
        'tags': tags,
        'notes': notes.map((n) => n.toJson()).toList(),
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (documents.isNotEmpty)
          'documents': documents.map((d) => d.toJson()).toList(),
      };

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final manifest = BackupManifest.fromJson(json);
    final rawNotes = json['notes'] as List? ?? [];
    final rawTags = json['tags'] as List? ?? [];
    final rawAttachments = json['attachments'] as List? ?? [];
    final rawDocuments = json['documents'] as List? ?? [];

    final notes = rawNotes
        .whereType<Map>()
        .map((e) => BackupNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final tags = rawTags.map((e) => e.toString()).toList();

    final attachments = rawAttachments
        .whereType<Map>()
        .map((e) => BackupAttachment.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final documents = rawDocuments
        .whereType<Map>()
        .map((e) => BackupDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return BackupPayload(
      manifest: manifest,
      notes: notes,
      tags: tags,
      attachments: attachments,
      documents: documents,
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
    this.totalDocumentsRestored = 0,
  });

  final int totalRestored;
  final int totalUpdated;
  final int totalSkipped;
  final int totalConflicts;
  final int totalTagsCreated;
  final int totalDocumentsRestored;
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
