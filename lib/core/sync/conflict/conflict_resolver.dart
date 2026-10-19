import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../crypto/crypto_service.dart';
import '../../crypto/key_manager.dart';
import '../../database/app_database.dart';
import '../../journal/application/journal_metadata_service.dart';
import '../../ocr/ocr_crypto.dart';
import '../../ocr/ocr_models.dart';
import '../../ocr/ocr_search_service.dart';
import 'conflict_model.dart';
import 'conflict_region.dart';
import 'markdown_merge_engine.dart';
import 'merge_result.dart';
import 'metadata_merge_engine.dart';

@immutable
class NoteMergeResult {
  const NoteMergeResult({
    required this.isClean,
    required this.mergedPlaintext,
    this.conflictType,
    this.conflictRegions = const [],
    this.isDeleted = false,
    this.explanation,
  });

  const NoteMergeResult.clean({
    required this.mergedPlaintext,
    this.isDeleted = false,
  })  : isClean = true,
        conflictType = null,
        conflictRegions = const [],
        explanation = null;

  const NoteMergeResult.conflicted({
    required this.mergedPlaintext,
    required this.conflictType,
    this.conflictRegions = const [],
    this.isDeleted = false,
    this.explanation,
  }) : isClean = false;

  final bool isClean;
  final NotePlaintext mergedPlaintext;
  final ConflictType? conflictType;
  final List<ConflictRegion> conflictRegions;
  final bool isDeleted;
  final String? explanation;

  bool get hasConflicts => !isClean || conflictRegions.isNotEmpty;
}

class ConflictResolver {
  ConflictResolver({
    required this.database,
    MetadataMergeEngine? metadataMergeEngine,
    MarkdownMergeEngine? markdownMergeEngine,
    this.keyManager,
    OcrCrypto? ocrCrypto,
    this.ocrSearchService,
  })  : metadataMergeEngine = metadataMergeEngine ?? const MetadataMergeEngine(),
        markdownMergeEngine = markdownMergeEngine ?? const MarkdownMergeEngine(),
        _ocrCrypto = ocrCrypto ?? OcrCrypto();

  final AppDatabase database;
  final MetadataMergeEngine metadataMergeEngine;
  final MarkdownMergeEngine markdownMergeEngine;
  final KeyManager? keyManager;
  final OcrCrypto _ocrCrypto;
  final OcrSearchService? ocrSearchService;

  /// Runs deterministic 3-way merge on note metadata and markdown content.
  NoteMergeResult merge3Way({
    required NotePlaintext? base,
    required NotePlaintext local,
    required NotePlaintext remote,
    bool localIsDeleted = false,
    bool remoteIsDeleted = false,
  }) {
    // 1. Check Delete-vs-Edit
    final localHasEdits = base == null ||
        base.body != local.body ||
        base.title != local.title ||
        !_listEquals(base.tags, local.tags);

    final remoteHasEdits = base == null ||
        base.body != remote.body ||
        base.title != remote.title ||
        !_listEquals(base.tags, remote.tags);

    final deleteResult = metadataMergeEngine.mergeDeleteVsEdit(
      baseDeleted: false,
      localDeleted: localIsDeleted,
      remoteDeleted: remoteIsDeleted,
      localHasEdits: localHasEdits,
      remoteHasEdits: remoteHasEdits,
    );

    if (deleteResult.conflictType == ConflictType.deleteVsEdit) {
      return NoteMergeResult.conflicted(
        mergedPlaintext: local,
        conflictType: ConflictType.deleteVsEdit,
        isDeleted: false,
        explanation: deleteResult.explanation ?? 'One device deleted this note while another device edited it.',
      );
    }

    if (deleteResult.mergedValue == true) {
      // Both branches agree on deletion
      return const NoteMergeResult.clean(
        mergedPlaintext: NotePlaintext(title: '', body: '', tags: []),
        isDeleted: true,
      );
    }

    // 2. Title Merge
    final titleResult = metadataMergeEngine.mergeTitle(
      base: base?.title,
      local: local.title,
      remote: remote.title,
    );

    // 3. Tags Merge
    final tagsResult = metadataMergeEngine.mergeTags(
      base: base?.tags,
      local: local.tags,
      remote: remote.tags,
    );

    // 4. Markdown Content Merge
    final contentResult = markdownMergeEngine.merge(
      base: base?.body,
      local: local.body,
      remote: remote.body,
    );

    // Per-tag pins survive a merge additively: union of both branches, kept
    // only for tags that remain after the tag merge.
    final mergedTagSet =
        tagsResult.mergedValue.map((t) => t.toLowerCase()).toSet();
    final mergedPinnedTags = <String>{
      ...local.pinnedTags,
      ...remote.pinnedTags,
    }.where((t) => mergedTagSet.contains(t.toLowerCase())).toList();

    final mergedPlaintext = NotePlaintext(
      title: titleResult.mergedValue,
      body: contentResult.mergedValue,
      tags: tagsResult.mergedValue,
      pinnedTags: mergedPinnedTags,
    );

    if (contentResult.hasConflicts) {
      return NoteMergeResult.conflicted(
        mergedPlaintext: mergedPlaintext,
        conflictType: ConflictType.content,
        conflictRegions: contentResult.conflictRegions,
        explanation: contentResult.explanation,
      );
    }

    if (titleResult.requiresManual) {
      return NoteMergeResult.conflicted(
        mergedPlaintext: mergedPlaintext,
        conflictType: ConflictType.title,
        explanation: titleResult.explanation,
      );
    }

    // Completely clean auto-merge!
    return NoteMergeResult.clean(mergedPlaintext: mergedPlaintext);
  }

  /// Automatically applies a clean 3-way merge commit to the database
  Future<void> applyAutoMerge({
    required String noteId,
    required NotePlaintext mergedPlaintext,
    required int baseRevision,
    required int localRevision,
    required int remoteRevision,
    required DateTime updatedAt,
  }) async {
    await database.transaction(() async {
      // 1. Get existing note
      final existing = await database.getNoteWithTags(noteId);
      if (existing == null) return;

      // 2. Save note version before merge (if not already recorded)
      final nextVer = await database.getNextVersionNumber(noteId);
      const uuid = Uuid();

      await database.saveNoteVersion(
        id: uuid.v4(),
        noteId: noteId,
        versionNumber: nextVer,
        title: mergedPlaintext.title,
        content: mergedPlaintext.body,
        tagsJson: jsonEncode(mergedPlaintext.tags),
        createdAt: DateTime.now(),
        charCount: mergedPlaintext.title.length + mergedPlaintext.body.length,
        wordCount: NotePlaintextWords.count(mergedPlaintext.body),
        deltaSummary: 'Merged changes from another device',
        serverRevision: remoteRevision,
        isDirty: true,
        baseRevision: baseRevision,
        localParentRevision: localRevision,
        remoteParentRevision: remoteRevision,
        mergeType: 'auto',
        resolutionSummary: 'Auto-merged independent non-conflicting edits',
      );

      // 3. Save note in DB with dirty flag for immediate push
      await database.saveNote(
        id: noteId,
        title: mergedPlaintext.title,
        content: mergedPlaintext.body,
        createdAt: existing.note.createdAt,
        updatedAt: updatedAt,
        isPinned: existing.note.isPinned,
        isArchived: existing.note.isArchived,
        isTrashed: existing.note.isTrashed,
        deletedAt: existing.note.deletedAt,
        tags: mergedPlaintext.tags,
        serverRevision: remoteRevision,
        isDirty: true,
      );

      // 4. Clean up any resolved conflict record
      await database.deleteConflictsForNote(noteId);
    });
  }

  /// Resolves conflict by keeping local branch
  Future<void> resolveKeepMine(SyncConflict conflict) async {
    if (conflict.isOcrConflict) {
      await resolveOcrKeepMine(conflict);
      return;
    }

    await database.transaction(() async {
      final noteId = conflict.noteId;
      final existing = await database.getNoteWithTags(noteId);
      if (existing == null) return;

      final nextVer = await database.getNextVersionNumber(noteId);
      const uuid = Uuid();

      await database.saveNoteVersion(
        id: uuid.v4(),
        noteId: noteId,
        versionNumber: nextVer,
        title: existing.note.title,
        content: existing.note.content,
        tagsJson: jsonEncode(existing.tagNames),
        createdAt: DateTime.now(),
        charCount: existing.note.title.length + existing.note.content.length,
        wordCount: NotePlaintextWords.count(existing.note.content),
        deltaSummary: 'Kept local version',
        serverRevision: conflict.remoteRevision,
        isDirty: true,
        baseRevision: conflict.baseRevision,
        localParentRevision: conflict.localRevision,
        remoteParentRevision: conflict.remoteRevision,
        mergeType: 'keepMine',
        resolutionSummary: 'Resolved by keeping local version',
      );

      // Mark note dirty with baseRevision = remoteRevision so server accepts the push
      await database.saveNote(
        id: noteId,
        title: existing.note.title,
        content: existing.note.content,
        createdAt: existing.note.createdAt,
        updatedAt: DateTime.now(),
        isPinned: existing.note.isPinned,
        isArchived: existing.note.isArchived,
        isTrashed: existing.note.isTrashed,
        deletedAt: existing.note.deletedAt,
        tags: existing.tagNames,
        serverRevision: conflict.remoteRevision,
        isDirty: true,
      );

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'keepMine',
      );
    });
  }

  /// Resolves conflict by keeping remote branch
  Future<void> resolveKeepTheirs(SyncConflict conflict) async {
    if (conflict.isOcrConflict) {
      await resolveOcrKeepTheirs(conflict);
      return;
    }

    await database.transaction(() async {
      final noteId = conflict.noteId;
      final remote = conflict.remotePlaintext;
      if (remote == null) return;

      final existing = await database.getNoteWithTags(noteId);
      final nextVer = await database.getNextVersionNumber(noteId);
      const uuid = Uuid();

      await database.saveNoteVersion(
        id: uuid.v4(),
        noteId: noteId,
        versionNumber: nextVer,
        title: remote.title,
        content: remote.body,
        tagsJson: jsonEncode(remote.tags),
        createdAt: DateTime.now(),
        charCount: remote.title.length + remote.body.length,
        wordCount: NotePlaintextWords.count(remote.body),
        deltaSummary: 'Applied remote version',
        serverRevision: conflict.remoteRevision,
        isDirty: false,
        syncedAt: DateTime.now(),
        baseRevision: conflict.baseRevision,
        localParentRevision: conflict.localRevision,
        remoteParentRevision: conflict.remoteRevision,
        mergeType: 'keepTheirs',
        resolutionSummary: 'Resolved by keeping remote version',
      );

      if (conflict.remoteIsDeleted) {
        await database.deletePermanently(noteId, enqueueSync: false);
      } else {
        await database.saveNote(
          id: noteId,
          title: remote.title,
          content: remote.body,
          createdAt: existing?.note.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
          isPinned: existing?.note.isPinned ?? false,
          isArchived: existing?.note.isArchived ?? false,
          isTrashed: existing?.note.isTrashed ?? false,
          tags: remote.tags,
          serverRevision: conflict.remoteRevision,
          isDirty: false,
          syncedAt: DateTime.now(),
        );
      }

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'keepTheirs',
      );
    });
  }

  /// Resolves conflict by keeping both branches as separate notes
  Future<String> resolveKeepBoth(SyncConflict conflict) async {
    const uuid = Uuid();
    final newNoteId = uuid.v4();

    await database.transaction(() async {
      final origNoteId = conflict.noteId;
      final remote = conflict.remotePlaintext;

      // 1. Keep original note with local content
      final origNote = await database.getNoteWithTags(origNoteId);
      if (origNote != null) {
        await database.saveNote(
          id: origNoteId,
          title: origNote.note.title,
          content: origNote.note.content,
          createdAt: origNote.note.createdAt,
          updatedAt: DateTime.now(),
          isPinned: origNote.note.isPinned,
          isArchived: origNote.note.isArchived,
          isTrashed: origNote.note.isTrashed,
          tags: origNote.tagNames,
          serverRevision: conflict.remoteRevision,
          isDirty: true,
        );
      }

      // 2. Create second note with remote branch
      final remoteTitle = remote?.title.trim().isNotEmpty == true
          ? '${remote!.title.trim()} (Conflict Copy)'
          : 'Untitled (Conflict Copy)';
      final remoteContent = remote?.body ?? '';
      final cleanContent = JournalMetadataService.removeJournalFrontmatter(remoteContent);
      final remoteTags = remote?.tags ?? [];

      await database.saveNote(
        id: newNoteId,
        title: remoteTitle,
        content: cleanContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        tags: remoteTags,
        journalDate: null,
        serverRevision: 0,
        isDirty: true,
      );

      // Create version record for the conflict copy
      await database.saveNoteVersion(
        id: uuid.v4(),
        noteId: newNoteId,
        versionNumber: 1,
        title: remoteTitle,
        content: remoteContent,
        tagsJson: jsonEncode(remoteTags),
        createdAt: DateTime.now(),
        charCount: remoteTitle.length + remoteContent.length,
        wordCount: NotePlaintextWords.count(remoteContent),
        deltaSummary: 'Created conflict copy from remote branch',
        serverRevision: 0,
        isDirty: true,
        mergeType: 'keepBoth',
        resolutionSummary: 'Separated conflict branch into new note',
      );

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'keepBoth',
      );
    });

    return newNoteId;
  }

  /// Resolves conflict with user-edited title, content, and tags
  Future<void> resolveWithCustomMerge({
    required SyncConflict conflict,
    required String resolvedTitle,
    required String resolvedContent,
    required List<String> resolvedTags,
  }) async {
    if (conflict.isOcrConflict) {
      await resolveOcrManual(
        conflict: conflict,
        resolvedContent: resolvedContent,
      );
      return;
    }

    await database.transaction(() async {
      final noteId = conflict.noteId;
      final existing = await database.getNoteWithTags(noteId);
      final nextVer = await database.getNextVersionNumber(noteId);
      const uuid = Uuid();

      await database.saveNoteVersion(
        id: uuid.v4(),
        noteId: noteId,
        versionNumber: nextVer,
        title: resolvedTitle,
        content: resolvedContent,
        tagsJson: jsonEncode(resolvedTags),
        createdAt: DateTime.now(),
        charCount: resolvedTitle.length + resolvedContent.length,
        wordCount: NotePlaintextWords.count(resolvedContent),
        deltaSummary: 'Resolved sync conflict',
        serverRevision: conflict.remoteRevision,
        isDirty: true,
        baseRevision: conflict.baseRevision,
        localParentRevision: conflict.localRevision,
        remoteParentRevision: conflict.remoteRevision,
        mergeType: 'manual',
        resolutionSummary: 'Manually merged conflicting changes',
      );

      await database.saveNote(
        id: noteId,
        title: resolvedTitle,
        content: resolvedContent,
        createdAt: existing?.note.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: existing?.note.isPinned ?? false,
        isArchived: existing?.note.isArchived ?? false,
        isTrashed: existing?.note.isTrashed ?? false,
        tags: resolvedTags,
        serverRevision: conflict.remoteRevision,
        isDirty: true,
      );

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'manual',
      );
    });
  }

  /// Resolves an OCR conflict by keeping the local OCR text version
  Future<void> resolveOcrKeepMine(SyncConflict conflict) async {
    final extra = conflict.extraData ?? {};
    final resourceType = extra['resourceType'] as String? ?? 'document';
    final resourceId = extra['resourceId'] as String? ?? conflict.noteId;
    final pageNumber = (extra['pageNumber'] as num?)?.toInt() ?? 1;

    await database.transaction(() async {
      if (resourceType == 'document') {
        final local = await database.getDocumentOcrPage(resourceId, pageNumber);
        if (local != null) {
          await database.saveDocumentOcrPage(
            documentId: resourceId,
            pageNumber: pageNumber,
            encryptedPayload: local.encryptedPayload,
            ocrSchemaVersion: local.ocrSchemaVersion,
            ocrEngine: local.ocrEngine,
            ocrEngineVersion: local.ocrEngineVersion,
            language: local.language,
            processedAt: local.processedAt,
            revision: conflict.remoteRevision,
            baseRevision: conflict.remoteRevision,
            isDirty: true,
            updatedAt: DateTime.now(),
          );
        }
      } else {
        final local = await database.getAttachmentOcrPage(resourceId, pageNumber);
        if (local != null) {
          await database.saveAttachmentOcrPage(
            attachmentId: resourceId,
            pageNumber: pageNumber,
            encryptedPayload: local.encryptedPayload,
            ocrSchemaVersion: local.ocrSchemaVersion,
            ocrEngine: local.ocrEngine,
            ocrEngineVersion: local.ocrEngineVersion,
            language: local.language,
            processedAt: local.processedAt,
            revision: conflict.remoteRevision,
            baseRevision: conflict.remoteRevision,
            isDirty: true,
            updatedAt: DateTime.now(),
          );
        }
      }

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'keepMine',
      );
    });
  }

  /// Resolves an OCR conflict by applying the remote server OCR text version
  Future<void> resolveOcrKeepTheirs(SyncConflict conflict) async {
    final extra = conflict.extraData ?? {};
    final resourceType = extra['resourceType'] as String? ?? 'document';
    final resourceId = extra['resourceId'] as String? ?? conflict.noteId;
    final pageNumber = (extra['pageNumber'] as num?)?.toInt() ?? 1;

    String? remotePayload = extra['remoteEncryptedPayload'] as String?;
    if ((remotePayload == null || remotePayload.isEmpty) &&
        keyManager != null &&
        keyManager!.isUnlocked &&
        conflict.remotePlaintext?.body != null) {
      final doc = OcrDocument(
        documentId: resourceId,
        processedAt: DateTime.now(),
        pages: [
          OcrPage(
            pageNumber: pageNumber,
            plainText: conflict.remotePlaintext!.body,
            width: 0,
            height: 0,
          ),
        ],
      );
      final bytes = await _ocrCrypto.encryptOcrDocument(
        ocrDocument: doc,
        masterKeyBytes: keyManager!.getMasterKey(),
      );
      remotePayload = base64Encode(bytes);
    }

    await database.transaction(() async {
      if (remotePayload != null && remotePayload.isNotEmpty) {
        if (resourceType == 'document') {
          await database.saveDocumentOcrPage(
            documentId: resourceId,
            pageNumber: pageNumber,
            encryptedPayload: remotePayload,
            processedAt: DateTime.now(),
            revision: conflict.remoteRevision,
            baseRevision: conflict.remoteRevision,
            isDirty: false,
            isDeleted: conflict.remoteIsDeleted,
            updatedAt: DateTime.now(),
          );
          if (!conflict.remoteIsDeleted) {
            await database.updateDocumentOcrState(resourceId, 'available');
          }
        } else {
          await database.saveAttachmentOcrPage(
            attachmentId: resourceId,
            pageNumber: pageNumber,
            encryptedPayload: remotePayload,
            processedAt: DateTime.now(),
            revision: conflict.remoteRevision,
            baseRevision: conflict.remoteRevision,
            isDirty: false,
            isDeleted: conflict.remoteIsDeleted,
            updatedAt: DateTime.now(),
          );
          if (!conflict.remoteIsDeleted) {
            await database.updateAttachmentOcrState(resourceId, 'available');
          }
        }
      }

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'keepTheirs',
      );
    });

    if (resourceType == 'document') {
      ocrSearchService?.invalidateDocumentCache(resourceId);
    } else {
      ocrSearchService?.invalidateAttachmentCache(resourceId);
    }
  }

  /// Resolves an OCR conflict with custom/merged OCR text
  Future<void> resolveOcrManual({
    required SyncConflict conflict,
    required String resolvedContent,
  }) async {
    final extra = conflict.extraData ?? {};
    final resourceType = extra['resourceType'] as String? ?? 'document';
    final resourceId = extra['resourceId'] as String? ?? conflict.noteId;
    final pageNumber = (extra['pageNumber'] as num?)?.toInt() ?? 1;

    if (keyManager == null || !keyManager!.isUnlocked) {
      throw StateError('KeyManager must be unlocked to resolve OCR conflicts manually');
    }
    final masterKey = keyManager!.getMasterKey();

    await database.transaction(() async {
      if (resourceType == 'document') {
        final existing = await database.getDocumentOcrPage(resourceId, pageNumber);
        OcrDocument? existingDoc;
        if (existing != null) {
          try {
            final envelopeBytes = base64Decode(existing.encryptedPayload);
            existingDoc = await _ocrCrypto.decryptOcrDocument(
              encryptedEnvelopeBytes: envelopeBytes,
              masterKeyBytes: masterKey,
              documentId: resourceId,
            );
          } catch (_) {}
        }

        final origPage = existingDoc?.pages.isNotEmpty == true ? existingDoc!.pages.first : null;
        final updatedPage = OcrPage(
          pageNumber: pageNumber,
          plainText: resolvedContent,
          width: origPage?.width ?? 0,
          height: origPage?.height ?? 0,
          blocks: origPage?.blocks ?? const [],
          source: origPage?.source ?? OcrSource.onDeviceOcr,
        );

        final updatedDoc = OcrDocument(
          documentId: resourceId,
          language: existingDoc?.language ?? OcrLanguage.english,
          engine: existingDoc?.engine ?? 'quietpaper_ocr_v1',
          engineVersion: existingDoc?.engineVersion ?? '1.0.0',
          schemaVersion: existingDoc?.schemaVersion ?? 1,
          processedAt: DateTime.now(),
          pages: [updatedPage],
        );

        final encBytes = await _ocrCrypto.encryptOcrDocument(
          ocrDocument: updatedDoc,
          masterKeyBytes: masterKey,
        );
        final payloadBase64 = base64Encode(encBytes);

        await database.saveDocumentOcrPage(
          documentId: resourceId,
          pageNumber: pageNumber,
          encryptedPayload: payloadBase64,
          ocrSchemaVersion: updatedDoc.schemaVersion,
          ocrEngine: updatedDoc.engine,
          ocrEngineVersion: updatedDoc.engineVersion,
          language: updatedDoc.language.code,
          processedAt: DateTime.now(),
          revision: conflict.remoteRevision,
          baseRevision: conflict.remoteRevision,
          isDirty: true,
          updatedAt: DateTime.now(),
        );
        await database.updateDocumentOcrState(resourceId, 'available');
      } else {
        final existing = await database.getAttachmentOcrPage(resourceId, pageNumber);
        OcrDocument? existingDoc;
        if (existing != null) {
          try {
            final envelopeBytes = base64Decode(existing.encryptedPayload);
            existingDoc = await _ocrCrypto.decryptOcrDocument(
              encryptedEnvelopeBytes: envelopeBytes,
              masterKeyBytes: masterKey,
              documentId: resourceId,
            );
          } catch (_) {}
        }

        final origPage = existingDoc?.pages.isNotEmpty == true ? existingDoc!.pages.first : null;
        final updatedPage = OcrPage(
          pageNumber: pageNumber,
          plainText: resolvedContent,
          width: origPage?.width ?? 0,
          height: origPage?.height ?? 0,
          blocks: origPage?.blocks ?? const [],
          source: origPage?.source ?? OcrSource.onDeviceOcr,
        );

        final updatedDoc = OcrDocument(
          documentId: resourceId,
          language: existingDoc?.language ?? OcrLanguage.english,
          engine: existingDoc?.engine ?? 'quietpaper_image_ocr',
          engineVersion: existingDoc?.engineVersion ?? '1.0.0',
          schemaVersion: existingDoc?.schemaVersion ?? 1,
          processedAt: DateTime.now(),
          pages: [updatedPage],
        );

        final encBytes = await _ocrCrypto.encryptOcrDocument(
          ocrDocument: updatedDoc,
          masterKeyBytes: masterKey,
        );
        final payloadBase64 = base64Encode(encBytes);

        await database.saveAttachmentOcrPage(
          attachmentId: resourceId,
          pageNumber: pageNumber,
          encryptedPayload: payloadBase64,
          ocrSchemaVersion: updatedDoc.schemaVersion,
          ocrEngine: updatedDoc.engine,
          ocrEngineVersion: updatedDoc.engineVersion,
          language: updatedDoc.language.code,
          processedAt: DateTime.now(),
          revision: conflict.remoteRevision,
          baseRevision: conflict.remoteRevision,
          isDirty: true,
          updatedAt: DateTime.now(),
        );
        await database.updateAttachmentOcrState(resourceId, 'available');
      }

      await database.markConflictResolved(
        conflict.id,
        resolutionRevision: conflict.remoteRevision,
        resolutionType: 'manual',
      );
    });

    if (resourceType == 'document') {
      ocrSearchService?.invalidateDocumentCache(resourceId);
    } else {
      ocrSearchService?.invalidateAttachmentCache(resourceId);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    final setB = b.toSet();
    return setA.length == setB.length && setA.containsAll(setB);
  }
}

class NotePlaintextWords {
  static int count(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }
}
