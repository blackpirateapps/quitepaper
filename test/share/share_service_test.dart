import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_models.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/cloudinary_client.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/share_models.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/core/uri/resource_resolver.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/share/application/share_service.dart';
import 'package:quitepaper/features/share/domain/note_share.dart';

/// Captures the arguments the API client received so the test can assert on
/// the content markdown that is actually published.
class _MockApiClient implements SyncApiClient {
  String? capturedMarkdown;
  String? capturedVisibility;
  String? capturedPassword;
  List<ShareAttachmentRef> capturedAttachments = const [];
  int uploadAuthCalls = 0;

  @override
  Future<CreatedShare> createShare({
    required String noteId,
    required String title,
    required String contentMarkdown,
    String visibility = 'public',
    String? password,
    List<ShareAttachmentRef> attachments = const [],
  }) async {
    capturedMarkdown = contentMarkdown;
    capturedVisibility = visibility;
    capturedPassword = password;
    capturedAttachments = attachments;
    return const CreatedShare(
      shareId: 'slug123',
      url: 'https://quietpaper.blackpiratex.com/note/slug123',
      visibility: 'public',
      title: 'T',
      createdAt: '2026-01-01T00:00:00Z',
      expiresAt: '2026-01-31T00:00:00Z',
    );
  }

  @override
  Future<CloudinaryUploadAuth> getShareUploadAuth({
    required String uploadId,
    String kind = 'image',
    String mimeType = 'image/png',
    int byteSize = 0,
  }) async {
    uploadAuthCalls++;
    return const CloudinaryUploadAuth(
      uploadUrl: 'https://api.cloudinary.com/v1_1/demo/image/upload',
      cloudName: 'demo',
      apiKey: 'key',
      signature: 'sig',
      timestamp: 1,
      publicId: 'quietpaper_public/asset',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockNotesRepository implements NotesRepository {
  String? savedShareId;
  String? savedShareUrl;

  @override
  Future<void> setNoteShareInfo(String noteId,
      {String? shareId, String? shareUrl}) async {
    savedShareId = shareId;
    savedShareUrl = shareUrl;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockAttachmentService implements AttachmentService {
  final Uint8List bytes;
  _MockAttachmentService(this.bytes);

  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(String assetId,
      {String variant = 'original'}) async {
    return ResourceResolution.available(
      QuietPaperUri.asset(assetId),
      bytes,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockCloudinaryClient implements CloudinaryClient {
  int uploadCount = 0;

  @override
  Future<CloudinaryUploadResult> uploadEncryptedBytes({
    required Uint8List encryptedBytes,
    required CloudinaryUploadAuth auth,
  }) async {
    uploadCount++;
    return const CloudinaryUploadResult(
      publicId: 'quietpaper_public/asset',
      secureUrl: 'https://res.cloudinary.com/demo/image/upload/asset.png',
      byteSize: 10,
      resourceType: 'image',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockAppDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // getAttachment(id) → null so ShareService falls back to image/png.
    if (invocation.memberName == #getAttachment) {
      return Future<AttachmentEntity?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

Note _note({String content = ''}) {
  final now = DateTime.utc(2026, 1, 1);
  return Note(
    id: 'note-1',
    title: 'My Note',
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiClient api;
  late _MockNotesRepository repo;
  late _MockCloudinaryClient cloud;
  late ShareService service;

  ShareService build({Uint8List? assetBytes}) {
    api = _MockApiClient();
    repo = _MockNotesRepository();
    cloud = _MockCloudinaryClient();
    return ShareService(
      apiClient: api,
      notesRepository: repo,
      attachmentService:
          _MockAttachmentService(assetBytes ?? Uint8List.fromList([1, 2, 3])),
      cloudinaryClient: cloud,
      database: _MockAppDatabase(),
    );
  }

  test('publishes plain markdown and persists the returned URL locally',
      () async {
    service = build();
    final created = await service.createShare(
      note: _note(),
      decryptedContent: 'Hello **world**',
      visibility: ShareVisibility.public,
    );

    expect(created.url, contains('/note/slug123'));
    expect(api.capturedMarkdown, 'Hello **world**');
    expect(api.capturedVisibility, 'public');
    expect(api.capturedAttachments, isEmpty);
    // The created URL is remembered on the note.
    expect(repo.savedShareId, 'slug123');
    expect(repo.savedShareUrl, contains('/note/slug123'));
  });

  test('strips leading YAML frontmatter from the published content', () async {
    service = build();
    const content = '---\ntitle: Secret\ntags: [a, b]\n---\nVisible body';
    await service.createShare(
      note: _note(content: content),
      decryptedContent: content,
      visibility: ShareVisibility.public,
    );

    expect(api.capturedMarkdown, 'Visible body');
    expect(api.capturedMarkdown, isNot(contains('title: Secret')));
  });

  test('rewrites qp://asset embeds to the uploaded public URL', () async {
    service = build();
    const content =
        'Look: ![diagram](qp://asset/11111111-1111-4111-8111-111111111111) '
        'and [file](qp://asset/22222222-2222-4222-8222-222222222222)';
    await service.createShare(
      note: _note(content: content),
      decryptedContent: content,
      visibility: ShareVisibility.public,
    );

    final md = api.capturedMarkdown!;
    expect(md, isNot(contains('qp://asset')));
    expect(md, contains('https://res.cloudinary.com/demo/image/upload/asset.png'));
    // Two distinct assets → two uploads → two attachment refs for GC.
    expect(cloud.uploadCount, 2);
    expect(api.capturedAttachments.length, 2);
  });

  test('uploads a repeated asset only once', () async {
    service = build();
    const content =
        '![a](qp://asset/33333333-3333-4333-8333-333333333333)\n\n'
        '![b](qp://asset/33333333-3333-4333-8333-333333333333)';
    await service.createShare(
      note: _note(content: content),
      decryptedContent: content,
      visibility: ShareVisibility.public,
    );

    expect(cloud.uploadCount, 1);
    expect(api.capturedAttachments.length, 1);
  });

  test('forwards the password for password-protected shares', () async {
    service = build();
    await service.createShare(
      note: _note(),
      decryptedContent: 'body',
      visibility: ShareVisibility.password,
      password: 'hunter2',
    );

    expect(api.capturedVisibility, 'password');
    expect(api.capturedPassword, 'hunter2');
  });

  test('rejects a password tier without a password', () async {
    service = build();
    expect(
      () => service.createShare(
        note: _note(),
        decryptedContent: 'body',
        visibility: ShareVisibility.password,
      ),
      throwsA(isA<ShareException>()),
    );
  });
}
