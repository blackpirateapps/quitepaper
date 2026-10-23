import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../sync/sync_models.dart';

/// Canonical asset taxonomy shown in Storage & Assets.
enum StorageAssetType {
  attachment('attachment'),
  document('document');

  const StorageAssetType(this.identifier);
  final String identifier;

  static StorageAssetType fromIdentifier(String? id) {
    if (id == 'document') return StorageAssetType.document;
    return StorageAssetType.attachment;
  }
}

/// Synchronization state of a merged asset item.
enum StorageAssetSyncState {
  synced('Synced'),
  localOnly('Local only'),
  cloudOnly('Cloud only'),
  pending('Upload pending'),
  failed('Upload failed');

  const StorageAssetSyncState(this.label);
  final String label;

  /// Maps a local `uploadState` column to a presentation sync state.
  static StorageAssetSyncState fromUploadState(String? uploadState) {
    switch (uploadState) {
      case 'synced':
        return StorageAssetSyncState.synced;
      case 'failed':
        return StorageAssetSyncState.failed;
      case 'upload_pending':
      case 'uploading':
      case 'uploaded':
        return StorageAssetSyncState.pending;
      case 'local_only':
      default:
        return StorageAssetSyncState.localOnly;
    }
  }
}

/// A single attachment or document, merged from local Drift rows and the
/// best-effort cloud resource listing.
@immutable
class StorageAssetItem {
  const StorageAssetItem({
    required this.id,
    required this.type,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.kind,
    required this.byteSize,
    required this.createdAt,
    required this.updatedAt,
    this.parentNoteId,
    this.parentNoteTitle,
    this.orphanedAt,
    this.isEligibleForDeletion = false,
    this.isOrphaned = false,
    required this.existsLocally,
    required this.existsInCloud,
    required this.syncState,
    this.attachmentEntity,
    this.documentEntity,
    this.cloudResource,
  });

  final String id;
  final StorageAssetType type;

  /// Display title. Documents use their title; attachments use the filename.
  final String title;

  /// User-visible filename.
  final String fileName;
  final String mimeType;

  /// `image`, `document`, `file`, or for documents `document`.
  final String kind;
  final int byteSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentNoteId;
  final String? parentNoteTitle;
  final DateTime? orphanedAt;
  final bool isEligibleForDeletion;
  final bool isOrphaned;
  final bool existsLocally;
  final bool existsInCloud;
  final StorageAssetSyncState syncState;
  final AttachmentEntity? attachmentEntity;
  final DocumentEntity? documentEntity;
  final StorageResourceItem? cloudResource;

  bool get isAttachment => type == StorageAssetType.attachment;
  bool get isDocument => type == StorageAssetType.document;

  /// Whether the asset is unreferenced by any note and eligible to be purged.
  bool get canBeDeleted => isOrphaned;

  /// Creates a merged item from a local attachment row.
  factory StorageAssetItem.fromAttachment({
    required AttachmentEntity entity,
    required bool existsLocally,
    required bool existsInCloud,
    String? parentNoteId,
    String? parentNoteTitle,
  }) {
    return StorageAssetItem(
      id: entity.id,
      type: StorageAssetType.attachment,
      title: entity.fileName,
      fileName: entity.fileName,
      mimeType: entity.mimeType,
      kind: entity.kind,
      byteSize: entity.byteSize,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      parentNoteId: parentNoteId ?? entity.noteId,
      parentNoteTitle: parentNoteTitle,
      existsLocally: existsLocally,
      existsInCloud: existsInCloud,
      syncState: StorageAssetSyncState.fromUploadState(entity.uploadState),
      attachmentEntity: entity,
    );
  }

  /// Creates a merged item from a local document row.
  factory StorageAssetItem.fromDocument({
    required DocumentEntity entity,
    required bool existsLocally,
    required bool existsInCloud,
    String? parentNoteId,
    String? parentNoteTitle,
  }) {
    return StorageAssetItem(
      id: entity.id,
      type: StorageAssetType.document,
      title: entity.title,
      fileName: entity.title,
      mimeType: entity.mimeType,
      kind: 'document',
      byteSize: entity.byteSize,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      parentNoteId: parentNoteId ?? entity.noteId,
      parentNoteTitle: parentNoteTitle,
      existsLocally: existsLocally,
      existsInCloud: existsInCloud,
      syncState: StorageAssetSyncState.fromUploadState(entity.uploadState),
      documentEntity: entity,
    );
  }

  /// Creates a cloud-only item from a backend storage resource row.
  factory StorageAssetItem.fromCloud(
    StorageResourceItem resource, {
    String? parentNoteTitle,
  }) {
    final type = StorageAssetType.fromIdentifier(resource.type);
    final cloudFileName = resource.fileName?.trim() ?? '';
    final cloudTitle = resource.title.trim();
    final fallbackName = type == StorageAssetType.document
        ? 'Scanned Document'
        : 'Attachment';
    final fileName = cloudFileName.isNotEmpty
        ? cloudFileName
        : (cloudTitle.isNotEmpty ? cloudTitle : fallbackName);

    return StorageAssetItem(
      id: resource.id,
      type: type,
      title: cloudTitle.isNotEmpty ? cloudTitle : fileName,
      fileName: fileName,
      mimeType: resource.mimeType.isNotEmpty
          ? resource.mimeType
          : (type == StorageAssetType.document
              ? 'application/pdf'
              : 'application/octet-stream'),
      kind: resource.kind?.isNotEmpty == true
          ? resource.kind!
          : (type == StorageAssetType.document ? 'document' : 'image'),
      byteSize: resource.byteSize,
      createdAt: resource.createdAt,
      updatedAt: resource.updatedAt,
      parentNoteId: resource.parentNoteId,
      parentNoteTitle: parentNoteTitle,
      orphanedAt: resource.orphanedAt,
      isEligibleForDeletion: resource.isEligibleForDeletion,
      isOrphaned: resource.status != 'referenced',
      existsLocally: false,
      existsInCloud: true,
      syncState: StorageAssetSyncState.cloudOnly,
      cloudResource: resource,
    );
  }

  StorageAssetItem copyWith({
    String? title,
    String? fileName,
    String? parentNoteId,
    String? parentNoteTitle,
    DateTime? orphanedAt,
    bool? isEligibleForDeletion,
    bool? isOrphaned,
    bool? existsLocally,
    bool? existsInCloud,
    StorageAssetSyncState? syncState,
    AttachmentEntity? attachmentEntity,
    DocumentEntity? documentEntity,
    StorageResourceItem? cloudResource,
  }) {
    return StorageAssetItem(
      id: id,
      type: type,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType,
      kind: kind,
      byteSize: byteSize,
      createdAt: createdAt,
      updatedAt: updatedAt,
      parentNoteId: parentNoteId ?? this.parentNoteId,
      parentNoteTitle: parentNoteTitle ?? this.parentNoteTitle,
      orphanedAt: orphanedAt ?? this.orphanedAt,
      isEligibleForDeletion:
          isEligibleForDeletion ?? this.isEligibleForDeletion,
      isOrphaned: isOrphaned ?? this.isOrphaned,
      existsLocally: existsLocally ?? this.existsLocally,
      existsInCloud: existsInCloud ?? this.existsInCloud,
      syncState: syncState ?? this.syncState,
      attachmentEntity: attachmentEntity ?? this.attachmentEntity,
      documentEntity: documentEntity ?? this.documentEntity,
      cloudResource: cloudResource ?? this.cloudResource,
    );
  }
}

/// Locally computed asset view: Drift rows plus note reference projections.
@immutable
class StorageLocalAssets {
  const StorageLocalAssets({
    required this.attachments,
    required this.documents,
    required this.referencedAttachmentIds,
    required this.referencedDocumentIds,
    required this.noteTitles,
  });

  final List<StorageAssetItem> attachments;
  final List<StorageAssetItem> documents;
  final Set<String> referencedAttachmentIds;
  final Set<String> referencedDocumentIds;
  final Map<String, String> noteTitles;

  List<StorageAssetItem> get all => [...attachments, ...documents];

  int get totalCount => attachments.length + documents.length;

  int get totalBytes =>
      all.fold<int>(0, (sum, item) => sum + item.byteSize);
}

/// Best-effort cloud listing result. Never throws; failures are captured so the
/// local asset view can continue to render offline.
@immutable
class StorageCloudResources {
  const StorageCloudResources({
    this.resources,
    required this.available,
    this.error,
  });

  const StorageCloudResources.unavailable([this.error])
      : resources = null,
        available = false;

  final StorageResourcesResponse? resources;
  final bool available;
  final String? error;
}

/// Merged local-first asset snapshot used by Storage & Assets.
@immutable
class StorageAssetsSnapshot {
  const StorageAssetsSnapshot({
    required this.attached,
    required this.orphaned,
    this.cloudAvailable = false,
    this.cloudError,
    this.cloudPending = false,
  });

  final List<StorageAssetItem> attached;
  final List<StorageAssetItem> orphaned;
  final bool cloudAvailable;
  final String? cloudError;
  final bool cloudPending;

  int get localCount => _all.where((item) => item.existsLocally).length;
  int get cloudCount => _all.where((item) => item.existsInCloud).length;
  int get totalCount => attached.length + orphaned.length;
  int get orphanedCount => orphaned.length;

  int get localBytes => _all
      .where((item) => item.existsLocally)
      .fold<int>(0, (sum, item) => sum + item.byteSize);

  int get totalBytes =>
      _all.fold<int>(0, (sum, item) => sum + item.byteSize);

  List<StorageAssetItem> get _all => [...attached, ...orphaned];

  /// Merges local rows with the cloud listing, deduping by asset ID.
  ///
  /// Local note references always count. Cloud status is authoritative when
  /// available. Local-only rows remain visible when the cloud call fails.
  factory StorageAssetsSnapshot.merge({
    required StorageLocalAssets local,
    required StorageCloudResources cloud,
    bool cloudPending = false,
  }) {
    final cloudByKey = <String, StorageResourceItem>{};
    for (final resource in cloud.resources?.attached ?? const []) {
      cloudByKey['${resource.type}:${resource.id}'] = resource;
    }
    for (final resource in cloud.resources?.orphaned ?? const []) {
      cloudByKey['${resource.type}:${resource.id}'] = resource;
    }

    final attached = <StorageAssetItem>[];
    final orphaned = <StorageAssetItem>[];
    final consumedKeys = <String>{};

    String keyFor(StorageAssetItem item) =>
        '${item.type.identifier}:${item.id}';

    bool isLocallyReferenced(StorageAssetItem item) {
      if (item.isDocument) {
        return local.referencedDocumentIds.contains(item.id);
      }
      return local.referencedAttachmentIds.contains(item.id);
    }

    for (final item in local.all) {
      final key = keyFor(item);
      final cloudResource = cloudByKey[key];
      if (cloudResource != null) {
        consumedKeys.add(key);
      }

      final cloudReferenced = cloudResource?.status == 'referenced';
      final referenced = isLocallyReferenced(item) || cloudReferenced;

      final parentNoteId = item.parentNoteId ?? cloudResource?.parentNoteId;
      final merged = item.copyWith(
        existsInCloud: cloud.resources != null
            ? cloudResource != null
            : item.existsInCloud,
        syncState: cloudResource != null
            ? StorageAssetSyncState.synced
            : item.syncState,
        cloudResource: cloudResource,
        parentNoteId: parentNoteId,
        parentNoteTitle: item.parentNoteTitle ??
            local.noteTitles[parentNoteId] ??
            local.noteTitles[cloudResource?.parentNoteId],
        isOrphaned: !referenced,
      );

      if (referenced) {
        attached.add(merged);
      } else {
        orphaned.add(
          merged.copyWith(
            orphanedAt: cloudResource?.orphanedAt,
            isEligibleForDeletion: cloudResource != null
                ? cloudResource.isEligibleForDeletion
                : true,
          ),
        );
      }
    }

    if (cloud.resources != null) {
      for (final entry in cloudByKey.entries) {
        if (consumedKeys.contains(entry.key)) continue;
        final resource = entry.value;
        final remoteOnly = StorageAssetItem.fromCloud(
          resource,
          parentNoteTitle: local.noteTitles[resource.parentNoteId],
        );
        if (resource.status == 'referenced') {
          attached.add(remoteOnly);
        } else {
          orphaned.add(remoteOnly.copyWith(isOrphaned: true));
        }
      }
    }

    int newestFirst(StorageAssetItem a, StorageAssetItem b) =>
        b.updatedAt.compareTo(a.updatedAt);
    attached.sort(newestFirst);
    orphaned.sort(newestFirst);

    return StorageAssetsSnapshot(
      attached: attached,
      orphaned: orphaned,
      cloudAvailable: cloud.available,
      cloudError: cloud.error,
      cloudPending: cloudPending,
    );
  }
}
