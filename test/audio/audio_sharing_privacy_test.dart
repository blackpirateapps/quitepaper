import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
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
import 'package:quitepaper/features/share/presentation/share_warning_dialog.dart';

class _MockApiClient implements SyncApiClient {
  String? capturedMarkdown;
  List<ShareAttachmentRef> capturedAttachments = const [];

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
    capturedAttachments = attachments;
    return const CreatedShare(
      shareId: 'slug-privacy-test',
      url: 'https://quietpaper.blackpiratex.com/note/slug-privacy-test',
      visibility: 'public',
      title: 'Privacy Note',
      createdAt: '2026-10-21T00:00:00Z',
      expiresAt: '2026-11-21T00:00:00Z',
    );
  }

  @override
  Future<CloudinaryUploadAuth> getShareUploadAuth({
    required String uploadId,
    String kind = 'image',
    String mimeType = 'image/png',
    int byteSize = 0,
  }) async {
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockNotesRepository implements NotesRepository {
  @override
  Future<void> setNoteShareInfo(String noteId, {String? shareId, String? shareUrl}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAttachmentService implements AttachmentService {
  @override
  Future<ResourceResolution<Uint8List>> resolveAsset(
    String assetId, {
    String variant = 'original',
  }) async {
    return ResourceResolution.available(
      QuietPaperUri.asset(assetId),
      Uint8List.fromList([1, 2, 3, 4]),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      publicId: 'quietpaper_public/img',
      secureUrl: 'https://res.cloudinary.com/demo/image/upload/img.png',
      byteSize: 10,
      resourceType: 'image',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAppDatabase implements AppDatabase {
  final Map<String, AttachmentEntity> attachments = {};

  @override
  Future<AttachmentEntity?> getAttachment(String id) async {
    return attachments[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Note _buildNote({required String content}) {
  final now = DateTime.utc(2026, 10, 21);
  return Note(
    id: 'note-1',
    title: 'Voice Diary',
    content: content,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Sharing Privacy Tests', () {
    late _MockAppDatabase db;
    late _MockApiClient apiClient;
    late _MockNotesRepository notesRepo;
    late _MockAttachmentService attachmentService;
    late _MockCloudinaryClient cloudinaryClient;
    late ShareService shareService;

    setUp(() {
      db = _MockAppDatabase();
      apiClient = _MockApiClient();
      notesRepo = _MockNotesRepository();
      attachmentService = _MockAttachmentService();
      cloudinaryClient = _MockCloudinaryClient();
      shareService = ShareService(
        apiClient: apiClient,
        database: db,
        notesRepository: notesRepo,
        attachmentService: attachmentService,
        cloudinaryClient: cloudinaryClient,
      );
    });

    test('excludes audio attachments from public shares and strips private URI', () async {
      const audioId = '11111111-1111-4111-8111-111111111111';
      final now = DateTime.now();

      db.attachments[audioId] = AttachmentEntity(
        id: audioId,
        fileName: 'recording_memo.m4a',
        mimeType: 'audio/mp4',
        byteSize: 500,
        sha256: 'abc',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final content = '# Thoughts\n\n[Confidential Recording](qp://asset/$audioId)\n\nWrap up.';
      final note = _buildNote(content: content);

      await shareService.createShare(
        note: note,
        decryptedContent: content,
        visibility: ShareVisibility.public,
      );

      // Verify Cloudinary was NEVER called to upload audio
      expect(cloudinaryClient.uploadCount, equals(0));

      // Verify private URI is stripped
      expect(apiClient.capturedMarkdown, isNot(contains(audioId)));
      expect(apiClient.capturedMarkdown, isNot(contains('qp://asset/')));

      // Verify omission notice is present
      expect(
        apiClient.capturedMarkdown,
        contains('> *[Voice memo excluded from public share]*'),
      );
      expect(apiClient.capturedMarkdown, contains('Wrap up.'));
    });

    test('excludes companion audio transcript blockquote when audio is stripped from share', () async {
      const audioId = '33333333-3333-4333-8333-333333333333';
      final now = DateTime.now();

      db.attachments[audioId] = AttachmentEntity(
        id: audioId,
        fileName: 'confidential_journal.m4a',
        mimeType: 'audio/mp4',
        byteSize: 1200,
        sha256: 'abc333',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      final content = '# Secret Diary\n\n'
          '[Audio Journal](qp://asset/$audioId?transcript=1&lang=en&edited=0)\n'
          '> Highly sensitive spoken reflection line 1.\n'
          '> Highly sensitive spoken reflection line 2.\n\n'
          'Publicly visible conclusion paragraph.';

      final note = _buildNote(content: content);

      await shareService.createShare(
        note: note,
        decryptedContent: content,
        visibility: ShareVisibility.public,
      );

      expect(cloudinaryClient.uploadCount, equals(0));
      expect(apiClient.capturedMarkdown, isNot(contains(audioId)));
      expect(apiClient.capturedMarkdown, isNot(contains('qp://asset/')));
      expect(apiClient.capturedMarkdown, isNot(contains('transcript=1')));

      // Voice memo omission notice
      expect(apiClient.capturedMarkdown, contains('> *[Voice memo excluded from public share]*'));

      // Sensitive spoken transcript MUST NOT leak
      expect(apiClient.capturedMarkdown, isNot(contains('Highly sensitive spoken reflection line 1')));
      expect(apiClient.capturedMarkdown, isNot(contains('Highly sensitive spoken reflection line 2')));

      // Public text remains intact
      expect(apiClient.capturedMarkdown, contains('Publicly visible conclusion paragraph.'));
    });

    test('mixed note uploads image but excludes audio', () async {
      const audioId = '11111111-1111-4111-8111-111111111111';
      const imageId = '22222222-2222-4222-8222-222222222222';
      final now = DateTime.now();

      db.attachments[audioId] = AttachmentEntity(
        id: audioId,
        fileName: 'recording_memo.m4a',
        mimeType: 'audio/mp4',
        byteSize: 500,
        sha256: 'abc',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      db.attachments[imageId] = AttachmentEntity(
        id: imageId,
        fileName: 'screenshot.png',
        mimeType: 'image/png',
        byteSize: 1200,
        sha256: 'def',
        kind: 'image',
        createdAt: now,
        updatedAt: now,
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'completed',
        ocrLanguage: 'en',
      );

      final content = '![Visual Diagram](qp://asset/$imageId)\n\n[Voice Notes](qp://asset/$audioId)';
      final note = _buildNote(content: content);

      await shareService.createShare(
        note: note,
        decryptedContent: content,
        visibility: ShareVisibility.public,
      );

      // Only 1 upload for the image
      expect(cloudinaryClient.uploadCount, equals(1));
      // Image was rewritten to public URL
      expect(apiClient.capturedMarkdown, contains('https://res.cloudinary.com/demo/image/upload/img.png'));
      // Audio was replaced by omission notice
      expect(apiClient.capturedMarkdown, contains('> *[Voice memo excluded from public share]*'));
      expect(apiClient.capturedMarkdown, isNot(contains(audioId)));
    });

    testWidgets('ShareWarningDialog shows voice recording disclaimer when hasAudio is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ShareWarningDialog(hasAudio: true),
          ),
        ),
      );

      expect(
        find.text('Voice recordings will be excluded from the public link to protect your privacy.'),
        findsOneWidget,
      );
    });

    testWidgets('ShareWarningDialog does not show audio disclaimer when hasAudio is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ShareWarningDialog(hasAudio: false),
          ),
        ),
      );

      expect(
        find.text('Voice recordings will be excluded from the public link to protect your privacy.'),
        findsNothing,
      );
    });
  });
}
