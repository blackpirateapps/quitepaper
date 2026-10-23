import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/storage/storage_management_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/presentation/storage_management_screen.dart';
import 'package:quitepaper/features/settings/presentation/widgets/storage_asset_details_sheet.dart';

class MockStorageSyncApiClient extends SyncApiClient {
  MockStorageSyncApiClient({this.failResources = false, this.resourcesResponse});

  final bool failResources;
  final StorageResourcesResponse? resourcesResponse;
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
    if (failResources) {
      throw const SocketException('offline');
    }
    final override = resourcesResponse;
    if (override != null) return override;
    return StorageResourcesResponse(
      attached: [
        StorageResourceItem(
          id: 'att-1',
          type: 'attachment',
          title: 'Diagram Screenshot',
          fileName: 'diagram.png',
          kind: 'image',
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
          fileName: 'old-photo.jpg',
          kind: 'image',
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
  late Directory attachmentsDir;
  late Directory documentsDir;
  late StorageManagementService service;

  const user = AuthUser(
    id: 'test-user',
    email: 'test@example.com',
    idToken: 'token',
  );

  StorageManagementService createService(MockStorageSyncApiClient client) {
    return StorageManagementService(
      apiClient: client,
      database: db,
      attachmentStorage: AttachmentLocalStorage(
        customBaseDirectory: attachmentsDir,
      ),
      documentStorage: DocumentLocalStorage(
        customDocumentsDirectory: documentsDir,
      ),
    );
  }

  setUp(() async {
    db = AppDatabase.memory();
    mockClient = MockStorageSyncApiClient();
    attachmentsDir = await Directory.systemTemp.createTemp('qp_storage_att_');
    documentsDir = await Directory.systemTemp.createTemp('qp_storage_doc_');
    service = createService(mockClient);
  });

  tearDown(() async {
    await db.close();
    if (await attachmentsDir.exists()) {
      await attachmentsDir.delete(recursive: true);
    }
    if (await documentsDir.exists()) {
      await documentsDir.delete(recursive: true);
    }
  });

  Widget buildApp({int initialTab = 0}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncApiClientProvider.overrideWithValue(mockClient),
        storageManagementServiceProvider.overrideWithValue(service),
        currentUserProvider.overrideWithValue(user),
      ],
      child: MaterialApp(
        home: StorageManagementScreen(initialTab: initialTab),
      ),
    );
  }

  Future<void> addLocalAttachment({
    required String id,
    String fileName = 'local-photo.png',
    String kind = 'image',
    String mimeType = 'image/png',
    String uploadState = 'local_only',
  }) async {
    await db.saveAttachment(
      id: id,
      fileName: fileName,
      kind: kind,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      mimeType: mimeType,
      byteSize: 1024,
      uploadState: uploadState,
    );
    File('${attachmentsDir.path}/$id.enc').writeAsBytesSync([1, 2, 3]);
  }

  Future<void> addReferencingNote(String attachmentId) async {
    await db.saveNote(
      id: 'note-1',
      title: 'Test Note',
      content: '![photo](qp://asset/$attachmentId)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
    );
  }

  test('StorageManagementService executes storage queries and GC', () async {
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

    await service.deleteOrphanedResource(
      resourceType: 'attachment',
      resourceId: 'att-2',
    );
    expect(mockClient.deletedResourceCalled, true);
  });

  testWidgets('StorageManagementScreen renders tabs, local summary and cloud data',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Verify title and tabs
    expect(find.text('Storage & Assets'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Attached'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Orphaned'), findsOneWidget);

    // Local-first summary and cloud breakdown
    expect(find.text('On This Device'), findsOneWidget);
    expect(find.text('Total Cloud Storage'), findsOneWidget);
    expect(find.text('15.0 MB'), findsOneWidget);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('2 active device(s)'), findsOneWidget);
    expect(find.text('STORAGE BREAKDOWN'), findsOneWidget);
    expect(find.text('Run Storage Cleanup (GC)'), findsOneWidget);

    // Switch to Attached tab
    await tester.tap(find.widgetWithText(Tab, 'Attached'));
    await tester.pumpAndSettle();
    expect(find.text('Diagram Screenshot'), findsOneWidget);
    expect(find.text('Cloud only'), findsOneWidget);

    // Switch to Orphaned tab
    await tester.tap(find.widgetWithText(Tab, 'Orphaned'));
    await tester.pumpAndSettle();
    expect(find.text('Old Unused Photo'), findsOneWidget);
    expect(find.text('Eligible for destruction'), findsOneWidget);
  });

  testWidgets('Local-only assets render while the cloud API fails', (tester) async {
    mockClient = MockStorageSyncApiClient(failResources: true);
    service = createService(mockClient);

    const id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    await addLocalAttachment(id: id);
    await addReferencingNote(id);

    await tester.pumpWidget(buildApp(initialTab: 1));
    await tester.pumpAndSettle();

    expect(find.text('local-photo.png'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(
      find.text('Cloud unavailable — showing on-device assets only'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Tapping a tile opens the details sheet', (tester) async {
    await tester.pumpWidget(buildApp(initialTab: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diagram Screenshot'));
    await tester.pumpAndSettle();

    expect(find.byType(StorageAssetDetailsSheet), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Cloud only'), findsWidgets);
    expect(find.text('Download to device'), findsOneWidget);
  });

  testWidgets('Orphan delete action asks for confirmation', (tester) async {
    const id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    await addLocalAttachment(id: id);

    await tester.pumpWidget(buildApp(initialTab: 2));
    await tester.pumpAndSettle();

    expect(find.text('local-photo.png'), findsOneWidget);

    await tester.tap(find.text('local-photo.png'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Orphaned Asset'), findsOneWidget);
    expect(
      find.text(
        'Permanently delete this asset from this device? This action cannot be undone.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Orphaned Asset'), findsNothing);
    expect(find.byType(StorageAssetDetailsSheet), findsOneWidget);
  });

  testWidgets('Asset status badges show all sync states', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const syncedId = '11111111-1111-1111-1111-111111111111';
    const localOnlyId = '22222222-2222-2222-2222-222222222222';
    const cloudOnlyId = '33333333-3333-3333-3333-333333333333';
    const pendingId = '44444444-4444-4444-4444-444444444444';
    const failedId = '55555555-5555-5555-5555-555555555555';
    final now = DateTime.now();

    await addLocalAttachment(
      id: syncedId,
      fileName: 'synced.png',
      uploadState: 'synced',
    );
    await addLocalAttachment(id: localOnlyId, fileName: 'local.png');
    await addLocalAttachment(
      id: pendingId,
      fileName: 'pending.png',
      uploadState: 'upload_pending',
    );
    await addLocalAttachment(
      id: failedId,
      fileName: 'failed.png',
      uploadState: 'failed',
    );
    await db.saveNote(
      id: 'note-badges',
      title: 'Badges',
      content: [
        '![a](qp://asset/$syncedId)',
        '![b](qp://asset/$localOnlyId)',
        '![c](qp://asset/$pendingId)',
        '![d](qp://asset/$failedId)',
      ].join('\n'),
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );

    mockClient = MockStorageSyncApiClient(
      resourcesResponse: StorageResourcesResponse(
        attached: [
          StorageResourceItem(
            id: syncedId,
            type: 'attachment',
            title: 'synced.png',
            fileName: 'synced.png',
            kind: 'image',
            mimeType: 'image/png',
            byteSize: 1024,
            createdAt: now,
            updatedAt: now,
            status: 'referenced',
            isEligibleForDeletion: false,
          ),
          StorageResourceItem(
            id: cloudOnlyId,
            type: 'attachment',
            title: 'cloud.png',
            fileName: 'cloud.png',
            kind: 'image',
            mimeType: 'image/png',
            byteSize: 1024,
            createdAt: now,
            updatedAt: now,
            status: 'referenced',
            isEligibleForDeletion: false,
          ),
        ],
        orphaned: const [],
        totalAttachedCount: 2,
        totalOrphanedCount: 0,
        totalStorageBytes: 2048,
      ),
    );
    service = createService(mockClient);

    await tester.pumpWidget(buildApp(initialTab: 1));
    await tester.pumpAndSettle();

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
    expect(find.text('Cloud only'), findsOneWidget);
    expect(find.text('Upload pending'), findsOneWidget);
    expect(find.text('Upload failed'), findsOneWidget);
  });
}
