import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/storage/storage_asset_models.dart';
import 'package:quitepaper/core/storage/storage_management_service.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_models.dart';

class _StorageTestApiClient extends SyncApiClient {
  _StorageTestApiClient({this.response, this.error});

  final StorageResourcesResponse? response;
  final Object? error;
  bool deletedResourceCalled = false;
  String? deletedResourceType;
  String? deletedResourceId;

  @override
  Future<StorageResourcesResponse> getStorageResources() async {
    if (error != null) throw error!;
    return response ??
        const StorageResourcesResponse(
          attached: [],
          orphaned: [],
          totalAttachedCount: 0,
          totalOrphanedCount: 0,
          totalStorageBytes: 0,
        );
  }

  @override
  Future<void> deleteStorageResource({
    required String resourceType,
    required String resourceId,
  }) async {
    deletedResourceCalled = true;
    deletedResourceType = resourceType;
    deletedResourceId = resourceId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory attachmentsDir;
  late Directory documentsDir;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase.memory();
    attachmentsDir = await Directory.systemTemp.createTemp('qp_assets_att_');
    documentsDir = await Directory.systemTemp.createTemp('qp_assets_doc_');
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

  StorageManagementService buildService(_StorageTestApiClient client) {
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

  Future<void> addAttachment({
    required String id,
    String fileName = 'photo.png',
    String kind = 'image',
    String mimeType = 'image/png',
    String uploadState = 'local_only',
    String? cloudUrl,
    bool createFile = true,
  }) async {
    await db.saveAttachment(
      id: id,
      fileName: fileName,
      kind: kind,
      createdAt: now,
      updatedAt: now,
      mimeType: mimeType,
      byteSize: 2048,
      sha256: 'sha-$id',
      uploadState: uploadState,
      cloudUrl: cloudUrl,
    );
    if (createFile) {
      await File('${attachmentsDir.path}/$id.enc').writeAsBytes([1, 2, 3]);
    }
  }

  Future<void> addDocument({
    required String id,
    String title = 'Scanned Note',
    String uploadState = 'local_only',
    String? cloudUrl,
    bool createFile = true,
  }) async {
    await db.saveDocument(
      id: id,
      title: title,
      source: 'scanner',
      createdAt: now,
      updatedAt: now,
      mimeType: 'application/pdf',
      byteSize: 4096,
      uploadState: uploadState,
      cloudUrl: cloudUrl,
    );
    if (createFile) {
      await File('${documentsDir.path}/$id.qpd').writeAsBytes([4, 5, 6]);
    }
  }

  Future<void> addNote(String id, String content) async {
    await db.saveNote(
      id: id,
      title: 'Test Note',
      content: content,
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );
  }

  StorageResourceItem cloudItem({
    required String id,
    String type = 'attachment',
    String status = 'referenced',
    String title = 'Cloud Asset',
    String? fileName,
    String? kind,
    String mimeType = 'image/png',
    DateTime? orphanedAt,
    bool isEligibleForDeletion = false,
  }) {
    return StorageResourceItem(
      id: id,
      type: type,
      title: title,
      fileName: fileName,
      kind: kind,
      mimeType: mimeType,
      byteSize: 1024,
      createdAt: now,
      updatedAt: now,
      status: status,
      orphanedAt: orphanedAt,
      isEligibleForDeletion: isEligibleForDeletion,
    );
  }

  StorageResourcesResponse cloudResponse({
    List<StorageResourceItem> attached = const [],
    List<StorageResourceItem> orphaned = const [],
  }) {
    return StorageResourcesResponse(
      attached: attached,
      orphaned: orphaned,
      totalAttachedCount: attached.length,
      totalOrphanedCount: orphaned.length,
      totalStorageBytes: (attached.length + orphaned.length) * 1024,
    );
  }

  test('local-only referenced attachment is Attached / Local only', () async {
    const id = '11111111-1111-1111-1111-111111111111';
    await addAttachment(id: id);
    await addNote('note-1', '![photo](qp://asset/$id)');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    expect(snapshot.orphaned, isEmpty);
    final item = snapshot.attached.first;
    expect(item.id, id);
    expect(item.syncState, StorageAssetSyncState.localOnly);
    expect(item.existsLocally, isTrue);
    expect(item.existsInCloud, isFalse);
    expect(item.parentNoteId, 'note-1');
    expect(item.parentNoteTitle, 'Test Note');
  });

  test('local + cloud attachment is Attached / Synced', () async {
    const id = '22222222-2222-2222-2222-222222222222';
    await addAttachment(id: id);
    await addNote('note-2', '![photo](qp://attachment/$id)');

    final snapshot = await buildService(
      _StorageTestApiClient(
        response: cloudResponse(
          attached: [cloudItem(id: id, fileName: 'photo.png', kind: 'image')],
        ),
      ),
    ).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    expect(snapshot.attached.first.syncState, StorageAssetSyncState.synced);
    expect(snapshot.attached.first.existsInCloud, isTrue);
    expect(snapshot.cloudAvailable, isTrue);
  });

  test('remote-only attachment is Attached / Cloud only with filename', () async {
    const id = '33333333-3333-3333-3333-333333333333';

    final snapshot = await buildService(
      _StorageTestApiClient(
        response: cloudResponse(
          attached: [
            cloudItem(
              id: id,
              fileName: 'report.pdf',
              kind: 'file',
              mimeType: 'application/pdf',
            ),
          ],
        ),
      ),
    ).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    final item = snapshot.attached.first;
    expect(item.syncState, StorageAssetSyncState.cloudOnly);
    expect(item.existsLocally, isFalse);
    expect(item.existsInCloud, isTrue);
    expect(item.fileName, 'report.pdf');
    expect(item.isOrphaned, isFalse);
  });

  test('local unreferenced attachment is Orphaned and deletable', () async {
    const id = '44444444-4444-4444-4444-444444444444';
    await addAttachment(id: id);
    await addNote('note-4', 'No references here.');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.attached, isEmpty);
    expect(snapshot.orphaned, hasLength(1));
    final item = snapshot.orphaned.first;
    expect(item.syncState, StorageAssetSyncState.localOnly);
    expect(item.isOrphaned, isTrue);
    expect(item.isEligibleForDeletion, isTrue);
  });

  test('remote orphaned attachment is Orphaned / Cloud only', () async {
    const id = '55555555-5555-5555-5555-555555555555';

    final snapshot = await buildService(
      _StorageTestApiClient(
        response: cloudResponse(
          orphaned: [
            cloudItem(
              id: id,
              status: 'orphaned',
              orphanedAt: now.subtract(const Duration(days: 20)),
              isEligibleForDeletion: true,
            ),
          ],
        ),
      ),
    ).getStorageAssets();

    expect(snapshot.attached, isEmpty);
    expect(snapshot.orphaned, hasLength(1));
    expect(snapshot.orphaned.first.syncState, StorageAssetSyncState.cloudOnly);
    expect(snapshot.orphaned.first.isEligibleForDeletion, isTrue);
  });

  test('cloud failure keeps local referenced assets visible', () async {
    const id = '66666666-6666-6666-6666-666666666666';
    await addAttachment(id: id);
    await addNote('note-6', '[file](qp://asset/$id)');

    final snapshot = await buildService(
      _StorageTestApiClient(error: const SocketException('offline')),
    ).getStorageAssets();

    expect(snapshot.cloudAvailable, isFalse);
    expect(snapshot.cloudError, isNotNull);
    expect(snapshot.attached, hasLength(1));
    expect(snapshot.attached.first.id, id);
  });

  test('link preview records are excluded', () async {
    const id = '77777777-7777-7777-7777-777777777777';
    await addAttachment(
      id: id,
      fileName: 'preview.png',
      kind: 'linkPreview',
    );
    await addNote('note-7', 'No references.');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.totalCount, 0);
  });

  test('audio attachments are included', () async {
    const id = '88888888-8888-8888-8888-888888888888';
    await addAttachment(
      id: id,
      fileName: 'recording_1234.m4a',
      kind: 'file',
      mimeType: 'audio/mp4',
    );
    await addNote('note-8', '[Recording](qp://asset/$id)');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    expect(snapshot.attached.first.mimeType, 'audio/mp4');
    expect(snapshot.attached.first.syncState, StorageAssetSyncState.localOnly);
  });

  test('local document with encrypted file is Attached / Local only', () async {
    const id = '99999999-9999-9999-9999-999999999999';
    await addDocument(id: id, title: 'Receipt Scan');
    await addNote('note-9', '[Receipt](qp://document/$id)');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    final item = snapshot.attached.first;
    expect(item.type, StorageAssetType.document);
    expect(item.title, 'Receipt Scan');
    expect(item.existsLocally, isTrue);
    expect(item.syncState, StorageAssetSyncState.localOnly);
  });

  test('upload failures surface as Upload failed', () async {
    const id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    await addAttachment(id: id, uploadState: 'failed');
    await addNote('note-10', '[file](qp://asset/$id)');

    final snapshot =
        await buildService(_StorageTestApiClient()).getStorageAssets();

    expect(snapshot.attached, hasLength(1));
    expect(snapshot.attached.first.syncState, StorageAssetSyncState.failed);
  });

  test('deleting a local-only orphan purges the row and file without cloud calls',
      () async {
    const id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
    await addAttachment(id: id);
    final client = _StorageTestApiClient();
    final service = buildService(client);
    final snapshot = await service.getStorageAssets();
    final item = snapshot.orphaned.single;

    await service.deleteOrphanedAsset(item);

    expect(await db.getAttachment(id), isNull);
    expect(File('${attachmentsDir.path}/$id.enc').existsSync(), isFalse);
    expect(client.deletedResourceCalled, isFalse);
  });

  test('deleting a synced orphan removes the cloud object and local copy',
      () async {
    const id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
    await addAttachment(id: id);
    final client = _StorageTestApiClient(
      response: cloudResponse(
        orphaned: [
          cloudItem(
            id: id,
            status: 'orphaned',
            orphanedAt: now.subtract(const Duration(days: 20)),
            isEligibleForDeletion: true,
          ),
        ],
      ),
    );
    final service = buildService(client);
    final snapshot = await service.getStorageAssets();
    final item = snapshot.orphaned.single;

    await service.deleteOrphanedAsset(item);

    expect(client.deletedResourceCalled, isTrue);
    expect(client.deletedResourceType, 'attachment');
    expect(client.deletedResourceId, id);
    expect(await db.getAttachment(id), isNull);
    expect(File('${attachmentsDir.path}/$id.enc').existsSync(), isFalse);
  });

  test('removeFromDeviceOnly keeps the cloud object', () async {
    const id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    await addAttachment(id: id);
    final client = _StorageTestApiClient(
      response: cloudResponse(
        orphaned: [
          cloudItem(
            id: id,
            status: 'orphaned',
            orphanedAt: now.subtract(const Duration(days: 20)),
            isEligibleForDeletion: true,
          ),
        ],
      ),
    );
    final service = buildService(client);
    final snapshot = await service.getStorageAssets();

    await service.deleteOrphanedAsset(
      snapshot.orphaned.single,
      removeFromDeviceOnly: true,
    );

    expect(client.deletedResourceCalled, isFalse);
    expect(await db.getAttachment(id), isNull);
  });
}
