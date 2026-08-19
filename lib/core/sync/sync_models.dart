import 'package:flutter/foundation.dart';

enum SyncStatus {
  localOnly,
  pendingSync,
  syncing,
  synced,
  offline,
  conflict,
  syncError,
}

@immutable
class SyncState {
  const SyncState({
    this.status = SyncStatus.localOnly,
    this.lastSyncedAt,
    this.errorMessage,
    this.pendingCount = 0,
    this.conflictsCount = 0,
    this.attachmentsPending = 0,
    this.attachmentsSynced = 0,
    this.attachmentsFailed = 0,
  });

  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int pendingCount;
  final int conflictsCount;
  final int attachmentsPending;
  final int attachmentsSynced;
  final int attachmentsFailed;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? pendingCount,
    int? conflictsCount,
    int? attachmentsPending,
    int? attachmentsSynced,
    int? attachmentsFailed,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
      conflictsCount: conflictsCount ?? this.conflictsCount,
      attachmentsPending: attachmentsPending ?? this.attachmentsPending,
      attachmentsSynced: attachmentsSynced ?? this.attachmentsSynced,
      attachmentsFailed: attachmentsFailed ?? this.attachmentsFailed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastSyncedAt == other.lastSyncedAt &&
          errorMessage == other.errorMessage &&
          pendingCount == other.pendingCount &&
          conflictsCount == other.conflictsCount &&
          attachmentsPending == other.attachmentsPending &&
          attachmentsSynced == other.attachmentsSynced &&
          attachmentsFailed == other.attachmentsFailed;

  @override
  int get hashCode =>
      status.hashCode ^
      lastSyncedAt.hashCode ^
      errorMessage.hashCode ^
      pendingCount.hashCode ^
      conflictsCount.hashCode ^
      attachmentsPending.hashCode ^
      attachmentsSynced.hashCode ^
      attachmentsFailed.hashCode;
}

@immutable
class NoteSyncPayload {
  const NoteSyncPayload({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.trashed,
    required this.pinned,
    this.folderId,
    this.sortOrder,
    required this.contentCiphertext,
    required this.contentNonce,
    this.contentVersion = 1,
    this.encryptionKeyVersion = 1,
    this.baseRevision,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool trashed;
  final bool pinned;
  final String? folderId;
  final double? sortOrder;
  final String contentCiphertext;
  final String contentNonce;
  final int contentVersion;
  final int encryptionKeyVersion;
  final int? baseRevision;
  final bool isDeleted;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archived': archived,
        'trashed': trashed,
        'pinned': pinned,
        if (folderId != null) 'folderId': folderId,
        if (sortOrder != null) 'sortOrder': sortOrder,
        'contentCiphertext': contentCiphertext,
        'contentNonce': contentNonce,
        'contentVersion': contentVersion,
        'encryptionKeyVersion': encryptionKeyVersion,
        if (baseRevision != null) 'baseRevision': baseRevision,
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      };

  factory NoteSyncPayload.fromJson(Map<String, dynamic> json) {
    return NoteSyncPayload(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archived: json['archived'] as bool? ?? false,
      trashed: json['trashed'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toDouble(),
      contentCiphertext: json['contentCiphertext'] as String? ?? '',
      contentNonce: json['contentNonce'] as String? ?? '',
      contentVersion: json['contentVersion'] as int? ?? 1,
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      baseRevision: json['baseRevision'] as int?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
    );
  }
}

@immutable
class PushResultItem {
  const PushResultItem({
    required this.id,
    required this.revision,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final int revision;
  final String status;
  final DateTime updatedAt;

  factory PushResultItem.fromJson(Map<String, dynamic> json) {
    return PushResultItem(
      id: json['id'] as String,
      revision: json['revision'] as int,
      status: json['status'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

@immutable
class ConflictItem {
  const ConflictItem({
    required this.id,
    required this.serverRevision,
    this.baseRevision,
    required this.code,
    required this.message,
  });

  final String id;
  final int serverRevision;
  final int? baseRevision;
  final String code;
  final String message;

  factory ConflictItem.fromJson(Map<String, dynamic> json) {
    return ConflictItem(
      id: json['id'] as String,
      serverRevision: json['serverRevision'] as int,
      baseRevision: json['baseRevision'] as int?,
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

@immutable
class PushSyncResponse {
  const PushSyncResponse({
    required this.results,
    required this.conflicts,
    required this.cursor,
  });

  final List<PushResultItem> results;
  final List<ConflictItem> conflicts;
  final int cursor;

  factory PushSyncResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List? ?? [];
    final rawConflicts = json['conflicts'] as List? ?? [];
    return PushSyncResponse(
      results: rawResults
          .map((r) => PushResultItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      conflicts: rawConflicts
          .map((c) => ConflictItem.fromJson(c as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as int? ?? 0,
    );
  }
}

@immutable
class PullChangeItem {
  const PullChangeItem({
    required this.id,
    required this.revision,
    required this.changeType,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.trashed,
    required this.pinned,
    this.folderId,
    this.sortOrder,
    required this.contentCiphertext,
    required this.contentNonce,
    this.contentVersion = 1,
    this.encryptionKeyVersion = 1,
    this.deletedAt,
  });

  final String id;
  final int revision;
  final String changeType; // 'upsert' | 'delete'
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool trashed;
  final bool pinned;
  final String? folderId;
  final double? sortOrder;
  final String contentCiphertext;
  final String contentNonce;
  final int contentVersion;
  final int encryptionKeyVersion;
  final DateTime? deletedAt;

  bool get isDeleted => changeType == 'delete' || deletedAt != null;

  factory PullChangeItem.fromJson(Map<String, dynamic> json) {
    return PullChangeItem(
      id: json['id'] as String,
      revision: json['revision'] as int,
      changeType: json['changeType'] as String? ?? 'upsert',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      archived: json['archived'] as bool? ?? false,
      trashed: json['trashed'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toDouble(),
      contentCiphertext: json['contentCiphertext'] as String? ?? '',
      contentNonce: json['contentNonce'] as String? ?? '',
      contentVersion: json['contentVersion'] as int? ?? 1,
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
    );
  }
}

@immutable
class PullSyncResponse {
  const PullSyncResponse({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });

  final List<PullChangeItem> changes;
  final int cursor;
  final bool hasMore;

  factory PullSyncResponse.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List? ?? [];
    return PullSyncResponse(
      changes: rawChanges
          .map((c) => PullChangeItem.fromJson(c as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

@immutable
class NoteVersionSyncPayload {
  const NoteVersionSyncPayload({
    required this.id,
    required this.noteId,
    required this.versionNumber,
    required this.contentCiphertext,
    required this.contentNonce,
    this.charCount = 0,
    this.wordCount = 0,
    this.deltaSummary,
    required this.createdAt,
  });

  final String id;
  final String noteId;
  final int versionNumber;
  final String contentCiphertext;
  final String contentNonce;
  final int charCount;
  final int wordCount;
  final String? deltaSummary;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'versionNumber': versionNumber,
        'contentCiphertext': contentCiphertext,
        'contentNonce': contentNonce,
        'charCount': charCount,
        'wordCount': wordCount,
        if (deltaSummary != null) 'deltaSummary': deltaSummary,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteVersionSyncPayload.fromJson(Map<String, dynamic> json) {
    return NoteVersionSyncPayload(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      versionNumber: json['versionNumber'] as int,
      contentCiphertext: json['contentCiphertext'] as String? ?? '',
      contentNonce: json['contentNonce'] as String? ?? '',
      charCount: json['charCount'] as int? ?? 0,
      wordCount: json['wordCount'] as int? ?? 0,
      deltaSummary: json['deltaSummary'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

@immutable
class PushVersionSyncResponse {
  const PushVersionSyncResponse({
    required this.results,
    required this.cursor,
  });

  final List<PushResultItem> results;
  final int cursor;

  factory PushVersionSyncResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List? ?? [];
    return PushVersionSyncResponse(
      results: rawResults
          .map((r) => PushResultItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as int? ?? 0,
    );
  }
}

@immutable
class PullVersionChangeItem {
  const PullVersionChangeItem({
    required this.id,
    required this.noteId,
    required this.versionNumber,
    required this.contentCiphertext,
    required this.contentNonce,
    this.charCount = 0,
    this.wordCount = 0,
    this.deltaSummary,
    required this.revision,
    required this.createdAt,
  });

  final String id;
  final String noteId;
  final int versionNumber;
  final String contentCiphertext;
  final String contentNonce;
  final int charCount;
  final int wordCount;
  final String? deltaSummary;
  final int revision;
  final DateTime createdAt;

  factory PullVersionChangeItem.fromJson(Map<String, dynamic> json) {
    return PullVersionChangeItem(
      id: json['id'] as String,
      noteId: json['noteId'] as String,
      versionNumber: json['versionNumber'] as int,
      contentCiphertext: json['contentCiphertext'] as String? ?? '',
      contentNonce: json['contentNonce'] as String? ?? '',
      charCount: json['charCount'] as int? ?? 0,
      wordCount: json['wordCount'] as int? ?? 0,
      deltaSummary: json['deltaSummary'] as String?,
      revision: json['revision'] as int? ?? 1,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

@immutable
class PullVersionSyncResponse {
  const PullVersionSyncResponse({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });

  final List<PullVersionChangeItem> changes;
  final int cursor;
  final bool hasMore;

  factory PullVersionSyncResponse.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List? ?? [];
    return PullVersionSyncResponse(
      changes: rawChanges
          .map((c) => PullVersionChangeItem.fromJson(c as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
