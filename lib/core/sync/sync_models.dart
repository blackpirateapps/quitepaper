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
class ServerHeadSyncPayload {
  const ServerHeadSyncPayload({
    required this.revision,
    required this.contentCiphertext,
    required this.contentNonce,
    this.contentVersion = 1,
    this.encryptionKeyVersion = 1,
    this.isDeleted = false,
    this.deletedAt,
    this.archived = false,
    this.trashed = false,
    this.pinned = false,
    this.folderId,
    this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final int revision;
  final String contentCiphertext;
  final String contentNonce;
  final int contentVersion;
  final int encryptionKeyVersion;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool archived;
  final bool trashed;
  final bool pinned;
  final String? folderId;
  final double? sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ServerHeadSyncPayload.fromJson(Map<String, dynamic> json) {
    return ServerHeadSyncPayload(
      revision: json['revision'] as int? ?? 1,
      contentCiphertext: json['contentCiphertext'] as String? ?? '',
      contentNonce: json['contentNonce'] as String? ?? '',
      contentVersion: json['contentVersion'] as int? ?? 1,
      encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
      archived: json['archived'] as bool? ?? false,
      trashed: json['trashed'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'revision': revision,
        'contentCiphertext': contentCiphertext,
        'contentNonce': contentNonce,
        'contentVersion': contentVersion,
        'encryptionKeyVersion': encryptionKeyVersion,
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        'archived': archived,
        'trashed': trashed,
        'pinned': pinned,
        if (folderId != null) 'folderId': folderId,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

@immutable
class ConflictItem {
  const ConflictItem({
    required this.id,
    this.noteId,
    required this.serverRevision,
    this.baseRevision,
    required this.code,
    required this.message,
    this.serverHead,
  });

  final String id;
  final String? noteId;
  final int serverRevision;
  final int? baseRevision;
  final String code;
  final String message;
  final ServerHeadSyncPayload? serverHead;

  factory ConflictItem.fromJson(Map<String, dynamic> json) {
    return ConflictItem(
      id: json['id'] as String,
      noteId: json['noteId'] as String?,
      serverRevision: json['serverRevision'] as int? ?? 0,
      baseRevision: json['baseRevision'] as int?,
      code: json['code'] as String? ?? 'SYNC_CONFLICT',
      message: json['message'] as String? ?? '',
      serverHead: json['serverHead'] != null
          ? ServerHeadSyncPayload.fromJson(
              json['serverHead'] as Map<String, dynamic>)
          : null,
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

  bool get isDeleted => changeType == 'delete';

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

class SyncCursorExpiredException implements Exception {
  const SyncCursorExpiredException({
    required this.message,
    this.minRetainedRevision = 0,
    this.currentRevision = 0,
  });

  final String message;
  final int minRetainedRevision;
  final int currentRevision;

  @override
  String toString() => message;
}

@immutable
class SyncReferenceItem {
  const SyncReferenceItem({
    required this.resourceType,
    required this.resourceId,
    required this.noteId,
  });

  final String resourceType; // 'attachment' | 'document'
  final String resourceId;
  final String noteId;

  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'resourceId': resourceId,
        'noteId': noteId,
      };

  factory SyncReferenceItem.fromJson(Map<String, dynamic> json) {
    return SyncReferenceItem(
      resourceType: json['resourceType'] as String,
      resourceId: json['resourceId'] as String,
      noteId: json['noteId'] as String,
    );
  }
}

@immutable
class StorageTableMetric {
  const StorageTableMetric({
    required this.rowCount,
    required this.approximatePayloadBytes,
    this.oldestTimestamp,
    this.newestTimestamp,
    required this.eligibleRowCount,
    required this.estimatedReclaimableBytes,
  });

  final int rowCount;
  final int approximatePayloadBytes;
  final String? oldestTimestamp;
  final String? newestTimestamp;
  final int eligibleRowCount;
  final int estimatedReclaimableBytes;

  factory StorageTableMetric.fromJson(Map<String, dynamic> json) {
    return StorageTableMetric(
      rowCount: json['rowCount'] as int? ?? 0,
      approximatePayloadBytes: json['approximatePayloadBytes'] as int? ?? 0,
      oldestTimestamp: json['oldestTimestamp'] as String?,
      newestTimestamp: json['newestTimestamp'] as String?,
      eligibleRowCount: json['eligibleRowCount'] as int? ?? 0,
      estimatedReclaimableBytes: json['estimatedReclaimableBytes'] as int? ?? 0,
    );
  }
}

@immutable
class StorageProfileReport {
  const StorageProfileReport({
    required this.userId,
    required this.generatedAt,
    required this.totalEstimatedBytes,
    required this.totalReclaimableBytes,
    required this.safeSyncBoundaryRevision,
    required this.activeDevicesCount,
    required this.staleDevicesCount,
    required this.expiredDevicesCount,
    required this.tables,
  });

  final String userId;
  final String generatedAt;
  final int totalEstimatedBytes;
  final int totalReclaimableBytes;
  final int safeSyncBoundaryRevision;
  final int activeDevicesCount;
  final int staleDevicesCount;
  final int expiredDevicesCount;
  final Map<String, StorageTableMetric> tables;

  factory StorageProfileReport.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'] as Map<String, dynamic>? ?? {};
    final parsedTables = <String, StorageTableMetric>{};
    for (final entry in rawTables.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsedTables[entry.key] = StorageTableMetric.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return StorageProfileReport(
      userId: json['userId'] as String? ?? '',
      generatedAt: json['generatedAt'] as String? ?? '',
      totalEstimatedBytes: json['totalEstimatedBytes'] as int? ?? 0,
      totalReclaimableBytes: json['totalReclaimableBytes'] as int? ?? 0,
      safeSyncBoundaryRevision: json['safeSyncBoundaryRevision'] as int? ?? 0,
      activeDevicesCount: json['activeDevicesCount'] as int? ?? 0,
      staleDevicesCount: json['staleDevicesCount'] as int? ?? 0,
      expiredDevicesCount: json['expiredDevicesCount'] as int? ?? 0,
      tables: parsedTables,
    );
  }
}

@immutable
class StorageResourceItem {
  const StorageResourceItem({
    required this.id,
    required this.type,
    required this.title,
    required this.mimeType,
    required this.byteSize,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.orphanedAt,
    required this.isEligibleForDeletion,
    this.parentNoteId,
    this.cloudUrl,
  });

  final String id;
  final String type; // 'attachment' | 'document'
  final String title;
  final String mimeType;
  final int byteSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'referenced' | 'orphaned' | 'pending_deletion'
  final DateTime? orphanedAt;
  final bool isEligibleForDeletion;
  final String? parentNoteId;
  final String? cloudUrl;

  factory StorageResourceItem.fromJson(Map<String, dynamic> json) {
    return StorageResourceItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'attachment',
      title: json['title'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      byteSize: json['byteSize'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: json['status'] as String? ?? 'referenced',
      orphanedAt: json['orphanedAt'] != null ? DateTime.tryParse(json['orphanedAt'] as String) : null,
      isEligibleForDeletion: json['isEligibleForDeletion'] as bool? ?? false,
      parentNoteId: json['parentNoteId'] as String?,
      cloudUrl: json['cloudUrl'] as String?,
    );
  }
}

@immutable
class StorageResourcesResponse {
  const StorageResourcesResponse({
    required this.attached,
    required this.orphaned,
    required this.totalAttachedCount,
    required this.totalOrphanedCount,
    required this.totalStorageBytes,
  });

  final List<StorageResourceItem> attached;
  final List<StorageResourceItem> orphaned;
  final int totalAttachedCount;
  final int totalOrphanedCount;
  final int totalStorageBytes;

  factory StorageResourcesResponse.fromJson(Map<String, dynamic> json) {
    final rawAttached = json['attached'] as List? ?? [];
    final rawOrphaned = json['orphaned'] as List? ?? [];
    return StorageResourcesResponse(
      attached: rawAttached.map((e) => StorageResourceItem.fromJson(e as Map<String, dynamic>)).toList(),
      orphaned: rawOrphaned.map((e) => StorageResourceItem.fromJson(e as Map<String, dynamic>)).toList(),
      totalAttachedCount: json['totalAttachedCount'] as int? ?? 0,
      totalOrphanedCount: json['totalOrphanedCount'] as int? ?? 0,
      totalStorageBytes: json['totalStorageBytes'] as int? ?? 0,
    );
  }
}

@immutable
class GcExecutionSummary {
  const GcExecutionSummary({
    required this.runId,
    required this.userId,
    required this.dryRun,
    required this.startedAt,
    required this.finishedAt,
    required this.durationMs,
    required this.safeSyncBoundaryRevision,
    required this.syncChangesDeleted,
    required this.noteVersionsDeleted,
    required this.idempotencyKeysDeleted,
    required this.orphanedAttachmentsIdentified,
    required this.orphanedDocumentsIdentified,
    required this.destructionJobsCreated,
    required this.destructionJobsProcessed,
    required this.destructionJobsCompleted,
    required this.destructionJobsFailed,
    required this.tombstonesCleaned,
    required this.estimatedBytesReclaimed,
    this.profile,
  });

  final String runId;
  final String userId;
  final bool dryRun;
  final String startedAt;
  final String finishedAt;
  final int durationMs;
  final int safeSyncBoundaryRevision;
  final int syncChangesDeleted;
  final int noteVersionsDeleted;
  final int idempotencyKeysDeleted;
  final int orphanedAttachmentsIdentified;
  final int orphanedDocumentsIdentified;
  final int destructionJobsCreated;
  final int destructionJobsProcessed;
  final int destructionJobsCompleted;
  final int destructionJobsFailed;
  final int tombstonesCleaned;
  final int estimatedBytesReclaimed;
  final StorageProfileReport? profile;

  factory GcExecutionSummary.fromJson(Map<String, dynamic> json) {
    return GcExecutionSummary(
      runId: json['runId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      dryRun: json['dryRun'] as bool? ?? false,
      startedAt: json['startedAt'] as String? ?? '',
      finishedAt: json['finishedAt'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
      safeSyncBoundaryRevision: json['safeSyncBoundaryRevision'] as int? ?? 0,
      syncChangesDeleted: json['syncChangesDeleted'] as int? ?? 0,
      noteVersionsDeleted: json['noteVersionsDeleted'] as int? ?? 0,
      idempotencyKeysDeleted: json['idempotencyKeysDeleted'] as int? ?? 0,
      orphanedAttachmentsIdentified: json['orphanedAttachmentsIdentified'] as int? ?? 0,
      orphanedDocumentsIdentified: json['orphanedDocumentsIdentified'] as int? ?? 0,
      destructionJobsCreated: json['destructionJobsCreated'] as int? ?? 0,
      destructionJobsProcessed: json['destructionJobsProcessed'] as int? ?? 0,
      destructionJobsCompleted: json['destructionJobsCompleted'] as int? ?? 0,
      destructionJobsFailed: json['destructionJobsFailed'] as int? ?? 0,
      tombstonesCleaned: json['tombstonesCleaned'] as int? ?? 0,
      estimatedBytesReclaimed: json['estimatedBytesReclaimed'] as int? ?? 0,
      profile: json['profile'] != null
          ? StorageProfileReport.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

@immutable
class TagSyncPayload {
  const TagSyncPayload({
    required this.id,
    required this.contentCiphertext,
    required this.contentNonce,
    this.contentVersion = 1,
    this.encryptionKeyVersion = 1,
    this.isPinned = false,
    this.pinnedOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.baseRevision,
  });

  final String id;
  final String contentCiphertext;
  final String contentNonce;
  final int contentVersion;
  final int encryptionKeyVersion;
  final bool isPinned;
  final int pinnedOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final int? baseRevision;

  Map<String, dynamic> toJson() => {
        'id': id,
        'contentCiphertext': contentCiphertext,
        'contentNonce': contentNonce,
        'contentVersion': contentVersion,
        'encryptionKeyVersion': encryptionKeyVersion,
        'isPinned': isPinned,
        'pinnedOrder': pinnedOrder,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (baseRevision != null) 'baseRevision': baseRevision,
      };

  factory TagSyncPayload.fromJson(Map<String, dynamic> json) => TagSyncPayload(
        id: json['id'] as String,
        contentCiphertext: json['contentCiphertext'] as String? ?? '',
        contentNonce: json['contentNonce'] as String? ?? '',
        contentVersion: json['contentVersion'] as int? ?? 1,
        encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
        isPinned: json['isPinned'] as bool? ?? false,
        pinnedOrder: json['pinnedOrder'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isDeleted: json['isDeleted'] as bool? ?? false,
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'] as String)
            : null,
        baseRevision: json['baseRevision'] as int?,
      );
}

@immutable
class PullTagChangeItem {
  const PullTagChangeItem({
    required this.id,
    required this.revision,
    required this.contentCiphertext,
    required this.contentNonce,
    this.contentVersion = 1,
    this.encryptionKeyVersion = 1,
    this.isPinned = false,
    this.pinnedOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  final String id;
  final int revision;
  final String contentCiphertext;
  final String contentNonce;
  final int contentVersion;
  final int encryptionKeyVersion;
  final bool isPinned;
  final int pinnedOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  factory PullTagChangeItem.fromJson(Map<String, dynamic> json) => PullTagChangeItem(
        id: json['id'] as String,
        revision: json['revision'] as int? ?? 1,
        contentCiphertext: json['contentCiphertext'] as String? ?? '',
        contentNonce: json['contentNonce'] as String? ?? '',
        contentVersion: json['contentVersion'] as int? ?? 1,
        encryptionKeyVersion: json['encryptionKeyVersion'] as int? ?? 1,
        isPinned: json['isPinned'] as bool? ?? false,
        pinnedOrder: json['pinnedOrder'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isDeleted: json['isDeleted'] as bool? ?? false,
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'] as String)
            : null,
      );
}

@immutable
class PullTagSyncResponse {
  const PullTagSyncResponse({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });

  final List<PullTagChangeItem> changes;
  final int cursor;
  final bool hasMore;

  factory PullTagSyncResponse.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List? ?? [];
    return PullTagSyncResponse(
      changes: rawChanges
          .map((c) => PullTagChangeItem.fromJson(c as Map<String, dynamic>))
          .toList(),
      cursor: json['cursor'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

