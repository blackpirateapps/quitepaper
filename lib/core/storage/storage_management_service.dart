import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../attachments/attachment_provider.dart';
import '../attachments/attachment_service.dart';
import '../attachments/attachment_storage.dart';
import '../database/app_database.dart';
import '../documents/document_provider.dart';
import '../documents/document_service.dart';
import '../documents/document_storage.dart';
import '../sync/sync_api_client.dart';
import '../sync/sync_models.dart';
import '../sync/sync_provider.dart';
import 'storage_asset_models.dart';

final storageManagementServiceProvider = Provider<StorageManagementService>((ref) {
  final apiClient = ref.watch(syncApiClientProvider);
  final database = ref.watch(databaseProvider);
  return StorageManagementService(
    apiClient: apiClient,
    database: database,
    attachmentStorage: ref.watch(attachmentLocalStorageProvider),
    documentStorage: ref.watch(documentLocalStorageProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
    documentService: ref.watch(documentServiceProvider),
  );
});

final storageProfileProvider = FutureProvider.autoDispose<StorageProfileReport>((ref) async {
  final service = ref.watch(storageManagementServiceProvider);
  return service.getStorageProfile();
});

/// Local Drift rows plus note-reference projection. Resolves without any
/// network access so the Storage & Assets page can render offline.
final localStorageAssetsProvider =
    FutureProvider.autoDispose<StorageLocalAssets>((ref) async {
  final service = ref.watch(storageManagementServiceProvider);
  return service.getLocalStorageAssets();
});

/// Best-effort cloud listing. Never throws; signed-out users skip the call.
final cloudStorageResourcesProvider =
    FutureProvider.autoDispose<StorageCloudResources>((ref) async {
  final signedIn = ref.watch(currentUserProvider) != null;
  if (!signedIn) {
    return const StorageCloudResources.unavailable(
      'Sign in to inspect cloud assets.',
    );
  }
  final service = ref.watch(storageManagementServiceProvider);
  return service.getCloudStorageResources();
});

/// Combined local-first view. Local rows render immediately; the cloud listing
/// merges in when available and never blocks the local list.
final storageAssetsProvider =
    Provider.autoDispose<AsyncValue<StorageAssetsSnapshot>>((ref) {
  final localAsync = ref.watch(localStorageAssetsProvider);
  final cloudAsync = ref.watch(cloudStorageResourcesProvider);

  final local = localAsync.valueOrNull;
  if (local == null) {
    if (localAsync.hasError) {
      return AsyncError(
        localAsync.error!,
        localAsync.stackTrace ?? StackTrace.current,
      );
    }
    return const AsyncLoading<StorageAssetsSnapshot>();
  }

  final cloudPending =
      cloudAsync.isLoading && !cloudAsync.hasValue && !cloudAsync.hasError;
  final cloud = cloudAsync.valueOrNull ??
      StorageCloudResources.unavailable(cloudAsync.error?.toString());

  return AsyncData(
    StorageAssetsSnapshot.merge(
      local: local,
      cloud: cloud,
      cloudPending: cloudPending,
    ),
  );
});

class StorageManagementService {
  StorageManagementService({
    required this.apiClient,
    required this.database,
    AttachmentLocalStorage? attachmentStorage,
    DocumentLocalStorage? documentStorage,
    this.attachmentService,
    this.documentService,
  })  : _attachmentStorage = attachmentStorage ?? AttachmentLocalStorage(),
        _documentStorage = documentStorage ?? DocumentLocalStorage();

  final SyncApiClient apiClient;
  final AppDatabase database;
  final AttachmentService? attachmentService;
  final DocumentService? documentService;
  final AttachmentLocalStorage _attachmentStorage;
  final DocumentLocalStorage _documentStorage;

  static final RegExp _attachmentReferencePattern = RegExp(
    r'qp://(?:attachment|asset)/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  );

  static final RegExp _documentReferencePattern = RegExp(
    r'qp://document/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  );

  Future<StorageProfileReport> getStorageProfile() async {
    return apiClient.getStorageProfile();
  }

  Future<StorageResourcesResponse> getStorageResources() async {
    return apiClient.getStorageResources();
  }

  /// Builds the local asset view from Drift rows and a single note scan.
  Future<StorageLocalAssets> getLocalStorageAssets() async {
    final notes = await database.getAllNotesRaw();
    final attachmentRows = await database.getAllAttachmentsRaw();
    final documentRows = await database.getAllDocumentsRaw();

    final referencedAttachmentIds = <String>{};
    final referencedDocumentIds = <String>{};
    final noteTitles = <String, String>{};
    final attachmentParentNotes = <String, String>{};
    final documentParentNotes = <String, String>{};

    for (final note in notes) {
      noteTitles[note.id] = note.title;
      final searchable = '${note.title}\n${note.content}';

      for (final match in _attachmentReferencePattern.allMatches(searchable)) {
        final id = match.group(1);
        if (id == null) continue;
        referencedAttachmentIds.add(id);
        attachmentParentNotes.putIfAbsent(id, () => note.id);
      }

      for (final match in _documentReferencePattern.allMatches(searchable)) {
        final id = match.group(1);
        if (id == null) continue;
        referencedDocumentIds.add(id);
        documentParentNotes.putIfAbsent(id, () => note.id);
      }
    }

    final attachments = await Future.wait(
      attachmentRows
          .where((entity) => !entity.isDeleted && entity.kind != 'linkPreview')
          .map((entity) async {
        final existsLocally = await _attachmentStorage.hasEncryptedFile(
          attachmentId: entity.id,
          localPath: entity.localPath,
        );
        final parentNoteId = entity.noteId ?? attachmentParentNotes[entity.id];
        return StorageAssetItem.fromAttachment(
          entity: entity,
          existsLocally: existsLocally,
          existsInCloud: _hasCloudCopy(entity.uploadState, entity.cloudUrl),
          parentNoteId: parentNoteId,
          parentNoteTitle: noteTitles[parentNoteId],
        );
      }),
    );

    final documents = await Future.wait(
      documentRows.where((entity) => !entity.isDeleted).map((entity) async {
        final existsLocally = await _documentStorage.hasEncryptedFile(
          documentId: entity.id,
        );
        final parentNoteId = entity.noteId ?? documentParentNotes[entity.id];
        return StorageAssetItem.fromDocument(
          entity: entity,
          existsLocally: existsLocally,
          existsInCloud: _hasCloudCopy(entity.uploadState, entity.cloudUrl),
          parentNoteId: parentNoteId,
          parentNoteTitle: noteTitles[parentNoteId],
        );
      }),
    );

    return StorageLocalAssets(
      attachments: attachments,
      documents: documents,
      referencedAttachmentIds: referencedAttachmentIds,
      referencedDocumentIds: referencedDocumentIds,
      noteTitles: noteTitles,
    );
  }

  /// Fetches the cloud resource listing with a bounded timeout. Any failure is
  /// returned as an unavailable state so the local view can still render.
  Future<StorageCloudResources> getCloudStorageResources({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final resources = await apiClient.getStorageResources().timeout(timeout);
      return StorageCloudResources(resources: resources, available: true);
    } catch (error) {
      return StorageCloudResources.unavailable(error.toString());
    }
  }

  /// Combined local-first snapshot. Convenience for tests and non-provider use.
  Future<StorageAssetsSnapshot> getStorageAssets() async {
    final local = await getLocalStorageAssets();
    final cloud = await getCloudStorageResources();
    return StorageAssetsSnapshot.merge(local: local, cloud: cloud);
  }

  Future<GcExecutionSummary> runDryRunGc() async {
    return apiClient.runGarbageCollection(dryRun: true);
  }

  Future<GcExecutionSummary> runGarbageCollection({int batchSize = 100}) async {
    return apiClient.runGarbageCollection(dryRun: false, batchSize: batchSize);
  }

  /// Permanently deletes an orphaned asset.
  ///
  /// When [removeFromDeviceOnly] is true the backend object is left untouched
  /// (for example when the device is offline) while local data is purged.
  Future<void> deleteOrphanedAsset(
    StorageAssetItem item, {
    bool removeFromDeviceOnly = false,
  }) async {
    if (item.existsInCloud && !removeFromDeviceOnly) {
      await apiClient.deleteStorageResource(
        resourceType: item.type.identifier,
        resourceId: item.id,
      );
    }

    if (item.existsLocally) {
      await purgeLocalAsset(item.type, item.id);
    }
  }

  /// Deletes an orphaned resource by ID. Cloud deletion can be skipped to
  /// support "Remove from this device only" while offline.
  Future<void> deleteOrphanedResource({
    required String resourceType,
    required String resourceId,
    bool deleteFromCloud = true,
  }) async {
    if (deleteFromCloud) {
      await apiClient.deleteStorageResource(
        resourceType: resourceType,
        resourceId: resourceId,
      );
    }

    await purgeLocalAsset(
      StorageAssetType.fromIdentifier(resourceType),
      resourceId,
    );
  }

  /// Purges the local encrypted file, derived rows, and pending sync queue
  /// entries for an attachment or document.
  Future<void> purgeLocalAsset(StorageAssetType type, String id) async {
    if (type == StorageAssetType.attachment) {
      if (attachmentService != null) {
        await attachmentService!.purgeLocalAttachment(id);
        return;
      }
      final entity = await database.getAttachment(id);
      if (entity == null) return;
      await database.deleteAttachmentVariants(id);
      await database.deleteAttachmentOcrPages(id);
      await database.removeSyncQueueEntriesForEntity(id);
      await _attachmentStorage.deleteEncryptedFile(
        attachmentId: id,
        localPath: entity.localPath,
      );
      await database.deleteAttachmentLocal(id);
      return;
    }

    if (documentService != null) {
      await documentService!.purgeLocalDocument(id);
      return;
    }
    final entity = await database.getDocument(id);
    if (entity == null) return;
    await database.deleteDocumentOcrPages(id);
    await database.deleteDocumentAnnotations(id);
    await database.removeSyncQueueEntriesForEntity(id);
    await _documentStorage.deleteEncryptedFile(documentId: id);
    await _documentStorage.deleteEncryptedAnnotatedFile(documentId: id);
    await database.deleteDocumentLocal(id);
  }

  static bool _hasCloudCopy(String uploadState, String? cloudUrl) {
    return uploadState == 'synced' ||
        (cloudUrl != null && cloudUrl.isNotEmpty);
  }
}
