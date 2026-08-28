import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/storage/storage_management_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/presentation/storage_management_screen.dart';

class MockStorageSyncApiClient extends SyncApiClient {
  bool gcRunCalled = false;
  bool deletedResourceCalled = false;

  @override
  Future<StorageProfileReport> getStorageProfile() async {
    return const StorageProfileReport(
      userId: 'test-user',
      generatedAt: '2026-08-28T12:00:00Z',
      totalEstimatedBytes: 15728640, // 15 MB
      totalReclaimableBytes: 5242880, // 5 MB
      safeSyncBoundaryRevision: 42,
      activeDevicesCount: 2,
      staleDevicesCount: 0,
      expiredDevicesCount: 0,
      tables: {
        'notes': StorageTableMetric(
          rowCount: 10,
          approximatePayloadBytes: 20480,
          eligibleRowCount: 0,
          estimatedReclaimableBytes: 0,
        ),
        'attachments': StorageTableMetric(
          rowCount: 4,
          approximatePayloadBytes: 10485760,
          eligibleRowCount: 1,
          estimatedReclaimableBytes: 2097152,
        ),
      },
    );
  }

  @override
  Future<StorageResourcesResponse> getStorageResources() async {
    return StorageResourcesResponse(
      attached: [
        StorageResourceItem(
          id: 'att-1',
          type: 'attachment',
          title: 'Diagram Screenshot',
          mimeType: 'image/png',
          byteSize: 1048576,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          updatedAt: DateTime.now().subtract(const Duration(days: 5)),
          status: 'referenced',
          isEligibleForDeletion: false,
        ),
      ],
      orphaned: [
        StorageResourceItem(
          id: 'att-2',
          type: 'attachment',
          title: 'Old Unused Photo',
          mimeType: 'image/jpeg',
          byteSize: 2097152,
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          updatedAt: DateTime.now().subtract(const Duration(days: 20)),
          status: 'orphaned',
          orphanedAt: DateTime.now().subtract(const Duration(days: 20)),
          isEligibleForDeletion: true,
        ),
      ],
      totalAttachedCount: 1,
      totalOrphanedCount: 1,
      totalStorageBytes: 3145728,
    );
  }

  @override
  Future<GcExecutionSummary> runGarbageCollection({
    bool dryRun = false,
    int batchSize = 100,
  }) async {
    gcRunCalled = true;
    return const GcExecutionSummary(
      runId: 'gc-run-1',
      userId: 'test-user',
      dryRun: false,
      startedAt: '2026-08-28T12:00:00Z',
      finishedAt: '2026-08-28T12:00:01Z',
      durationMs: 1000,
      safeSyncBoundaryRevision: 42,
      syncChangesDeleted: 15,
      noteVersionsDeleted: 8,
      idempotencyKeysDeleted: 3,
      orphanedAttachmentsIdentified: 1,
      orphanedDocumentsIdentified: 0,
      destructionJobsCreated: 1,
      destructionJobsProcessed: 1,
      destructionJobsCompleted: 1,
      destructionJobsFailed: 0,
      tombstonesCleaned: 2,
      estimatedBytesReclaimed: 5242880,
    );
  }

  @override
  Future<void> deleteStorageResource({
    required String resourceType,
    required String resourceId,
  }) async {
    deletedResourceCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockStorageSyncApiClient mockClient;

  setUp(() {
    db = AppDatabase.memory();
    mockClient = MockStorageSyncApiClient();
  });

  tearDown(() async {
    await db.close();
  });

  test('StorageManagementService executes storage queries and GC', () async {
    final service = StorageManagementService(
      apiClient: mockClient,
      database: db,
    );

    final profile = await service.getStorageProfile();
    expect(profile.totalEstimatedBytes, 15728640);
    expect(profile.totalReclaimableBytes, 5242880);
    expect(profile.activeDevicesCount, 2);

    final resources = await service.getStorageResources();
    expect(resources.attached.length, 1);
    expect(resources.orphaned.length, 1);
    expect(resources.orphaned.first.isEligibleForDeletion, true);

    final gcRes = await service.runGarbageCollection();
    expect(mockClient.gcRunCalled, true);
    expect(gcRes.syncChangesDeleted, 15);
    expect(gcRes.estimatedBytesReclaimed, 5242880);

    await service.deleteOrphanedResource(resourceType: 'attachment', resourceId: 'att-2');
    expect(mockClient.deletedResourceCalled, true);
  });

  testWidgets('StorageManagementScreen renders tabs and breakdown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          syncApiClientProvider.overrideWithValue(mockClient),
        ],
        child: const MaterialApp(
          home: StorageManagementScreen(initialTab: 0),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('Cloud Storage & Assets'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Attached'), findsOneWidget);
    expect(find.text('Orphaned'), findsOneWidget);

    // Verify Storage Breakdown
    expect(find.text('Total Cloud Storage'), findsOneWidget);
    expect(find.text('15.0 MB'), findsOneWidget);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('2 active device(s)'), findsOneWidget);
    expect(find.text('STORAGE BREAKDOWN'), findsOneWidget);
    expect(find.text('Run Storage Cleanup (GC)'), findsOneWidget);

    // Switch to Attached tab
    await tester.tap(find.text('Attached'));
    await tester.pumpAndSettle();
    expect(find.text('Diagram Screenshot'), findsOneWidget);

    // Switch to Orphaned tab
    await tester.tap(find.text('Orphaned'));
    await tester.pumpAndSettle();
    expect(find.text('Old Unused Photo'), findsOneWidget);
    expect(find.text('Eligible for destruction'), findsOneWidget);
  });
}
