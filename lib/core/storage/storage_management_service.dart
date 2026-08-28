import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../database/app_database.dart';
import '../sync/sync_api_client.dart';
import '../sync/sync_models.dart';
import '../sync/sync_provider.dart';

final storageManagementServiceProvider = Provider<StorageManagementService>((ref) {
  final apiClient = ref.watch(syncApiClientProvider);
  final database = ref.watch(databaseProvider);
  return StorageManagementService(
    apiClient: apiClient,
    database: database,
  );
});

final storageProfileProvider = FutureProvider.autoDispose<StorageProfileReport>((ref) async {
  final service = ref.watch(storageManagementServiceProvider);
  return service.getStorageProfile();
});

final storageResourcesProvider = FutureProvider.autoDispose<StorageResourcesResponse>((ref) async {
  final service = ref.watch(storageManagementServiceProvider);
  return service.getStorageResources();
});

class StorageManagementService {
  StorageManagementService({
    required this.apiClient,
    required this.database,
  });

  final SyncApiClient apiClient;
  final AppDatabase database;

  Future<StorageProfileReport> getStorageProfile() async {
    return apiClient.getStorageProfile();
  }

  Future<StorageResourcesResponse> getStorageResources() async {
    return apiClient.getStorageResources();
  }

  Future<GcExecutionSummary> runDryRunGc() async {
    return apiClient.runGarbageCollection(dryRun: true);
  }

  Future<GcExecutionSummary> runGarbageCollection({int batchSize = 100}) async {
    return apiClient.runGarbageCollection(dryRun: false, batchSize: batchSize);
  }

  Future<void> deleteOrphanedResource({
    required String resourceType,
    required String resourceId,
  }) async {
    // Delete on remote server
    await apiClient.deleteStorageResource(
      resourceType: resourceType,
      resourceId: resourceId,
    );

    // Delete locally if present
    if (resourceType == 'attachment') {
      await database.deleteAttachmentLocal(resourceId);
    } else if (resourceType == 'document') {
      await database.deleteDocumentLocal(resourceId);
    }
  }
}
