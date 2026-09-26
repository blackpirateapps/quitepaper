import 'package:flutter/foundation.dart';

import '../../../core/attachments/attachment_service.dart';
import '../../../core/attachments/cloudinary_client.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/share_models.dart';
import '../../../core/sync/sync_api_client.dart';
import '../../../core/uri/quiet_paper_uri.dart';
import '../../editor/application/frontmatter_editor_helper.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/note_share.dart';

/// Raised when preparing or creating a share fails, carrying a message safe to
/// surface in the UI.
class ShareException implements Exception {
  const ShareException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Progress phases reported while a share is being prepared and created.
enum ShareProgressPhase {
  preparing,
  uploadingAttachments,
  creatingShare,
  done,
}

/// Coordinates creating and managing public note shares.
///
/// Creating a share deliberately removes end-to-end encryption for the note: it
/// decrypts the note body and its referenced attachments locally, uploads the
/// plaintext to the backend (content) and Cloudinary (attachment files), and
/// records the resulting public URL on the note.
class ShareService {
  ShareService({
    required this.apiClient,
    required this.notesRepository,
    required this.attachmentService,
    required this.cloudinaryClient,
    required this.database,
  });

  final SyncApiClient apiClient;
  final NotesRepository notesRepository;
  final AttachmentService attachmentService;
  final CloudinaryClient cloudinaryClient;
  final AppDatabase database;

  // Matches image embeds: ![alt](uri)
  static final RegExp _imageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
  // Matches non-image links: [text](uri)
  static final RegExp _linkRegex = RegExp(r'(?<!!)\[([^\]]+)\]\(([^)]+)\)');

  /// Prepares and creates a public share for [note].
  ///
  /// [decryptedContent] is the current plaintext markdown body (the editor's
  /// live content, already unlocked if the note is password-protected).
  /// [onProgress] receives coarse phase updates for the UI.
  Future<CreatedShare> createShare({
    required Note note,
    required String decryptedContent,
    required ShareVisibility visibility,
    String? password,
    void Function(ShareProgressPhase phase)? onProgress,
  }) async {
    if (visibility == ShareVisibility.password &&
        (password == null || password.isEmpty)) {
      throw const ShareException(
        'A password is required for password-protected shares.',
      );
    }

    onProgress?.call(ShareProgressPhase.preparing);

    // 1. Strip internal YAML frontmatter so it is never published.
    final body = _stripFrontmatter(decryptedContent);

    // 2. Decrypt + upload referenced attachments, rewriting qp:// embeds to
    //    public https URLs.
    onProgress?.call(ShareProgressPhase.uploadingAttachments);
    final rewrite = await _uploadAndRewriteAttachments(body);

    // 3. Create the share on the backend.
    onProgress?.call(ShareProgressPhase.creatingShare);
    final CreatedShare created;
    try {
      created = await apiClient.createShare(
        noteId: note.id,
        title: note.displayTitle,
        contentMarkdown: rewrite.markdown,
        visibility: visibility.wireValue,
        password: password,
        attachments: rewrite.attachments,
      );
    } catch (e) {
      throw ShareException('Failed to create share: $e');
    }

    // 4. Remember the URL locally so the editor can show "Shared".
    try {
      await notesRepository.setNoteShareInfo(
        note.id,
        shareId: created.shareId,
        shareUrl: created.url,
      );
    } catch (e) {
      debugPrint('Share created but failed to persist locally: $e');
    }

    onProgress?.call(ShareProgressPhase.done);
    return created;
  }

  /// Lists the user's active shares for the management UI.
  Future<List<NoteShare>> listShares() async {
    final items = await apiClient.listShares();
    return items
        .map((i) => NoteShare.fromListItem(
              shareId: i.shareId,
              noteId: i.noteId,
              title: i.title,
              visibility: i.visibility,
              url: i.url,
              viewCount: i.viewCount,
              status: i.status,
              createdAt: i.createdAt,
              expiresAt: i.expiresAt,
            ))
        .toList();
  }

  /// Updates a share's visibility and/or password.
  Future<ShareVisibility> updateShare(
    String shareId, {
    ShareVisibility? visibility,
    String? password,
    bool clearPassword = false,
  }) async {
    final result = await apiClient.updateShare(
      shareId,
      visibility: visibility?.wireValue,
      password: password,
      clearPassword: clearPassword,
    );
    return ShareVisibility.fromWire(result.visibility);
  }

  /// Deletes (unshares) a share and clears the note's remembered URL when the
  /// deleted share matches what is stored locally.
  Future<void> deleteShare(String shareId, {String? noteId}) async {
    await apiClient.deleteShare(shareId);
    if (noteId == null) return;
    try {
      final note = await notesRepository.getNoteById(noteId);
      if (note != null && note.shareId == shareId) {
        await notesRepository.setNoteShareInfo(noteId, shareId: null, shareUrl: null);
      }
    } catch (e) {
      debugPrint('Failed to clear local share info for note $noteId: $e');
    }
  }

  /// Removes a leading YAML frontmatter block from [content], if present.
  String _stripFrontmatter(String content) {
    final doc = FrontmatterEditorHelper.parse(content);
    if (!doc.hasFrontmatter) return content;
    if (doc.bodyStartOffset <= 0 || doc.bodyStartOffset > content.length) {
      return content;
    }
    return content.substring(doc.bodyStartOffset).trimLeft();
  }

  /// Scans [markdown] for `qp://asset/<id>` references, decrypts and uploads
  /// each to the public Cloudinary folder, and rewrites the reference to the
  /// public https URL. Returns the rewritten markdown plus the attachment refs
  /// the backend needs for garbage collection.
  Future<({String markdown, List<ShareAttachmentRef> attachments})>
      _uploadAndRewriteAttachments(String markdown) async {
    // Collect unique asset references (image embeds and generic links).
    final references = <({String fullMatch, String label, bool isImage})>[];
    final seenAssetIds = <String>{};

    void collect(RegExp regex, bool isImage) {
      for (final match in regex.allMatches(markdown)) {
        final uriStr = match.group(2)!.trim();
        final qpUri = QuietPaperUri.tryParse(uriStr);
        if (qpUri != null && qpUri.isAsset) {
          references.add((
            fullMatch: match.group(0)!,
            label: match.group(1) ?? '',
            isImage: isImage,
          ));
        }
      }
    }

    collect(_imageRegex, true);
    collect(_linkRegex, false);

    if (references.isEmpty) {
      return (markdown: markdown, attachments: const <ShareAttachmentRef>[]);
    }

    var rewritten = markdown;
    final attachments = <ShareAttachmentRef>[];
    // Map assetId -> public URL so repeated references reuse a single upload.
    final uploadedUrls = <String, String>{};

    for (final ref in references) {
      final qpUri = QuietPaperUri.tryParse(
        // Re-extract the URI from the full match to get the exact id.
        _extractUri(ref.fullMatch),
      );
      if (qpUri == null || !qpUri.isAsset) continue;
      final assetId = qpUri.resourceId;

      var publicUrl = uploadedUrls[assetId];

      if (publicUrl == null && seenAssetIds.add(assetId)) {
        publicUrl = await _uploadSingleAsset(assetId, attachments);
        if (publicUrl != null) {
          uploadedUrls[assetId] = publicUrl;
        }
      }

      publicUrl ??= uploadedUrls[assetId];
      if (publicUrl == null) {
        // Could not resolve/upload; leave the reference untouched.
        continue;
      }

      final replacement = ref.isImage
          ? '![${ref.label}]($publicUrl)'
          : '[${ref.label}]($publicUrl)';
      rewritten = rewritten.replaceAll(ref.fullMatch, replacement);
    }

    return (markdown: rewritten, attachments: attachments);
  }

  /// Decrypts a single attachment and uploads it as public plaintext. Appends a
  /// [ShareAttachmentRef] on success and returns the public URL (or null).
  Future<String?> _uploadSingleAsset(
    String assetId,
    List<ShareAttachmentRef> attachments,
  ) async {
    try {
      final resolution = await attachmentService.resolveAsset(assetId);
      if (!resolution.isAvailable || resolution.data == null) {
        debugPrint('Skipping unavailable share attachment $assetId '
            '(${resolution.status.name})');
        return null;
      }
      final Uint8List bytes = resolution.data!;
      final entity = await database.getAttachment(assetId);
      final mimeType = entity?.mimeType ?? 'image/png';
      final kind = mimeType.startsWith('image/') ? 'image' : 'file';

      final auth = await apiClient.getShareUploadAuth(
        uploadId: assetId,
        kind: kind,
        mimeType: mimeType,
        byteSize: bytes.length,
      );

      final result = await cloudinaryClient.uploadEncryptedBytes(
        encryptedBytes: bytes,
        auth: auth,
      );

      attachments.add(ShareAttachmentRef(
        cloudPublicId: result.publicId,
        cloudUrl: result.secureUrl,
        resourceType: result.resourceType,
        byteSize: result.byteSize,
      ));
      return result.secureUrl;
    } catch (e) {
      debugPrint('Failed to upload share attachment $assetId: $e');
      return null;
    }
  }

  /// Extracts the URI portion from a full markdown image/link match.
  static String _extractUri(String fullMatch) {
    final open = fullMatch.lastIndexOf('(');
    final close = fullMatch.lastIndexOf(')');
    if (open < 0 || close < 0 || close <= open) return '';
    return fullMatch.substring(open + 1, close).trim();
  }
}
