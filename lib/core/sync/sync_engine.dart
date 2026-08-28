import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../attachments/attachment_sync_service.dart';
import '../auth/auth_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../documents/document_sync_service.dart';
import '../utils/debouncer.dart';
import 'conflict/conflict_model.dart';
import 'conflict/conflict_resolver.dart';
import 'conflict/merge_result.dart';
import 'sync_api_client.dart';
import 'sync_models.dart';

class SyncEngine {
  SyncEngine({
    required this.database,
    required this.cryptoService,
    required this.keyManager,
    required this.authService,
    required this.apiClient,
    this.attachmentSyncService,
    this.documentSyncService,
    ConflictResolver? conflictResolver,
  })  : conflictResolver = conflictResolver ?? ConflictResolver(database: database) {
    _init();
  }

  final AppDatabase database;
  final CryptoService cryptoService;
  final KeyManager keyManager;
  final AuthService authService;
  final SyncApiClient apiClient;
  final AttachmentSyncService? attachmentSyncService;
  final DocumentSyncService? documentSyncService;
  final ConflictResolver conflictResolver;

  final Debouncer _syncDebouncer =
      Debouncer(duration: const Duration(milliseconds: 700));
  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();

  SyncState get state => _state;
  Stream<SyncState> get stateStream => _stateController.stream;

  bool _isSyncing = false;

  void _init() {
    authService.authStateChanges.listen((user) {
      if (user == null) {
        _updateState(const SyncState(status: SyncStatus.localOnly));
      } else if (!keyManager.isUnlocked) {
        _updateState(_state.copyWith(status: SyncStatus.pendingSync));
      } else {
        triggerSyncDebounced();
      }
    });
  }

  void _updateState(SyncState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Triggers a debounced sync in the background
  void triggerSyncDebounced() {
    if (authService.currentUser == null || !keyManager.isUnlocked) return;
    _syncDebouncer.run(() {
      syncNow();
    });
  }

  /// Resets the sync cursor to 0 to trigger a full resync of all cloud notes
  Future<void> resetSyncCursor() async {
    await database.resetSyncCursors();
  }

  /// Triggers a full resync from cursor 0
  Future<void> fullResync() async {
    await resetSyncCursor();
    await syncNow();
  }

  /// Runs immediate push & pull synchronization
  Future<void> syncNow() async {
    if (_isSyncing) return;
    if (authService.currentUser == null) {
      _updateState(_state.copyWith(status: SyncStatus.localOnly));
      return;
    }
    if (!keyManager.isUnlocked) {
      _updateState(_state.copyWith(
        status: SyncStatus.pendingSync,
        errorMessage:
            'Quiet Paper encryption password is required to unlock notes.',
      ));
      return;
    }

    _isSyncing = true;
    _updateState(
        _state.copyWith(status: SyncStatus.syncing, errorMessage: null));

    try {
      final masterKey = keyManager.getMasterKey();

      // 1. Ensure remote encryption keys are initialized
      final storedKey = await keyManager.getStoredWrappedKeyData();
      if (storedKey != null) {
        final remoteKey = await apiClient.getKeys();
        if (remoteKey == null) {
          await apiClient.putKeys(storedKey);
        }
      }

      // 2. PUSH PHASE: Encrypt dirty notes and send to server
      final dirtyNotes = await database.getDirtyNotes();
      final pendingQueue = await database.getPendingSyncQueue();

      final pushItems = <({NoteSyncPayload payload, String? queueId})>[];

      for (final item in dirtyNotes) {
        final note = item.note;
        final tags = item.tagNames;

        final plaintext = NotePlaintext(
          title: note.title,
          body: note.content,
          tags: tags,
        );

        final envelope = await cryptoService.encryptNote(
          plaintext: plaintext,
          masterKeyBytes: masterKey,
          noteId: note.id,
          keyVersion: 1,
        );

        pushItems.add((
          payload: NoteSyncPayload(
            id: note.id,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            archived: note.isArchived,
            trashed: note.isTrashed,
            pinned: note.isPinned,
            contentCiphertext: envelope.ciphertext,
            contentNonce: envelope.nonce,
            contentVersion: envelope.contentVersion,
            encryptionKeyVersion: envelope.keyVersion,
            baseRevision: note.serverRevision > 0 ? note.serverRevision : null,
            deletedAt: note.deletedAt,
          ),
          queueId: null,
        ));
      }

      for (final queueItem in pendingQueue) {
        if (queueItem.operation == 'delete') {
          pushItems.add((
            payload: NoteSyncPayload(
              id: queueItem.noteId,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              archived: false,
              trashed: true,
              pinned: false,
              contentCiphertext: '',
              contentNonce: '',
              isDeleted: true,
              deletedAt: DateTime.now(),
            ),
            queueId: queueItem.id,
          ));
        }
      }

      if (pushItems.isNotEmpty) {
        const pushBatchSize = 100;

        for (var i = 0; i < pushItems.length; i += pushBatchSize) {
          final end = (i + pushBatchSize < pushItems.length)
              ? i + pushBatchSize
              : pushItems.length;
          final batch = pushItems.sublist(i, end);
          final batchPayloads = batch.map((item) => item.payload).toList();
          final batchQueueIds = batch
              .map((item) => item.queueId)
              .whereType<String>()
              .toList();

          const uuid = Uuid();
          final idempotencyKey = 'push_${uuid.v4()}';

          final pushResponse = await apiClient.pushChanges(
            changes: batchPayloads,
            idempotencyKey: idempotencyKey,
          );

          // Update local revisions for successfully applied notes
          for (final res in pushResponse.results) {
            await database.markNoteSynced(
              noteId: res.id,
              serverRevision: res.revision,
              syncedAt: DateTime.now(),
            );
          }

          // Remove processed deletion queue entries for this batch
          if (batchQueueIds.isNotEmpty) {
            await database.removeSyncQueueEntries(batchQueueIds);
          }

          if (pushResponse.conflicts.isNotEmpty) {
            await _processPushConflicts(pushResponse.conflicts, masterKey);
          }
        }
      }

      // 3. PULL PHASE: Fetch server changes after cursor
      final cursorStr = await database.getSyncMetadata('sync_cursor');
      var currentCursor = int.tryParse(cursorStr ?? '0') ?? 0;
      var hasMore = true;

      while (hasMore) {
        PullSyncResponse pullResponse;
        try {
          pullResponse =
              await apiClient.pullChanges(cursor: currentCursor, limit: 50);
        } on SyncCursorExpiredException catch (exp) {
          debugPrint('Sync cursor expired ($exp). Resetting cursor for full resync...');
          await resetSyncCursor();
          currentCursor = 0;
          pullResponse =
              await apiClient.pullChanges(cursor: 0, limit: 50);
        }

        for (final change in pullResponse.changes) {
          final conflictEntity =
              await database.getConflictForNote(change.id);
          final pendingConflict = conflictEntity != null
              ? SyncConflict.fromEntity(conflictEntity)
              : null;
          if (pendingConflict != null) {
            // Rebase pending conflict against newer remote revision
            if (change.revision > pendingConflict.remoteRevision) {
              try {
                NotePlaintext newRemote;
                if (change.isDeleted) {
                  newRemote = const NotePlaintext(title: '', body: '', tags: []);
                } else {
                  final env = EncryptedEnvelope(
                    version: change.contentVersion,
                    algorithm: 'xchacha20-poly1305',
                    keyVersion: change.encryptionKeyVersion,
                    nonce: change.contentNonce,
                    ciphertext: change.contentCiphertext,
                  );
                  newRemote = await cryptoService.decryptNote(
                    envelope: env,
                    masterKeyBytes: masterKey,
                    noteId: change.id,
                  );
                }

                final rebaseResult = conflictResolver.merge3Way(
                  base: pendingConflict.remotePlaintext,
                  local: pendingConflict.localPlaintext ??
                      const NotePlaintext(title: '', body: '', tags: []),
                  remote: newRemote,
                  localIsDeleted: pendingConflict.localIsDeleted,
                  remoteIsDeleted: change.isDeleted,
                );

                final updatedConflict = pendingConflict.copyWith(
                  remoteRevision: change.revision,
                  remotePlaintext: newRemote,
                  remoteIsDeleted: change.isDeleted,
                  conflictRegions: rebaseResult.conflictRegions,
                  conflictType:
                      rebaseResult.conflictType ?? pendingConflict.conflictType,
                  resolvedTitle: rebaseResult.mergedPlaintext.title,
                  resolvedContent: rebaseResult.mergedPlaintext.body,
                  resolvedTags: rebaseResult.mergedPlaintext.tags,
                );

                await database.saveConflict(
                  id: updatedConflict.id,
                  noteId: updatedConflict.noteId,
                  baseRevision: updatedConflict.baseRevision,
                  localRevision: updatedConflict.localRevision,
                  remoteRevision: updatedConflict.remoteRevision,
                  conflictType: updatedConflict.conflictType.name,
                  state: updatedConflict.state.name,
                  createdAt: updatedConflict.createdAt,
                  dataJson: updatedConflict.toDataJson(),
                );
              } catch (rebaseErr) {
                debugPrint(
                    'Failed to rebase conflict for note ${change.id}: $rebaseErr');
              }
            }
            continue;
          }

          if (change.isDeleted) {
            // Note was deleted on another device
            final localNote = await database.getNoteWithTags(change.id);
            if (localNote != null && localNote.note.isDirty) {
              // Delete-vs-Edit conflict on pull!
              final basePlaintext = await _fetchBasePlaintext(
                  change.id, localNote.note.serverRevision, masterKey);
              final localPlaintext = NotePlaintext(
                title: localNote.note.title,
                body: localNote.note.content,
                tags: localNote.tagNames,
              );
              const remotePlaintext =
                  NotePlaintext(title: '', body: '', tags: []);

              final mergeRes = conflictResolver.merge3Way(
                base: basePlaintext,
                local: localPlaintext,
                remote: remotePlaintext,
                localIsDeleted: false,
                remoteIsDeleted: true,
              );

              if (mergeRes.isClean) {
                if (mergeRes.isDeleted) {
                  await database.deletePermanently(change.id, enqueueSync: false);
                }
              } else {
                const uuid = Uuid();
                final conflict = SyncConflict(
                  id: uuid.v4(),
                  noteId: change.id,
                  baseRevision: localNote.note.serverRevision,
                  localRevision: localNote.note.serverRevision,
                  remoteRevision: change.revision,
                  conflictType: ConflictType.deleteVsEdit,
                  state: ConflictState.manualRequired,
                  createdAt: DateTime.now(),
                  basePlaintext: basePlaintext,
                  localPlaintext: localPlaintext,
                  remotePlaintext: remotePlaintext,
                  localIsDeleted: false,
                  remoteIsDeleted: true,
                  resolvedTitle: localPlaintext.title,
                  resolvedContent: localPlaintext.body,
                  resolvedTags: localPlaintext.tags,
                  explanation: 'Note was deleted on another device while being edited locally.',
                );
                await database.saveConflict(
                  id: conflict.id,
                  noteId: conflict.noteId,
                  baseRevision: conflict.baseRevision,
                  localRevision: conflict.localRevision,
                  remoteRevision: conflict.remoteRevision,
                  conflictType: conflict.conflictType.name,
                  state: conflict.state.name,
                  createdAt: conflict.createdAt,
                  dataJson: conflict.toDataJson(),
                );
              }
            } else {
              await database.deletePermanently(change.id, enqueueSync: false);
            }
          } else {
            // Decrypt note content
            try {
              final envelope = EncryptedEnvelope(
                version: change.contentVersion,
                algorithm: 'xchacha20-poly1305',
                keyVersion: change.encryptionKeyVersion,
                nonce: change.contentNonce,
                ciphertext: change.contentCiphertext,
              );

              final decrypted = await cryptoService.decryptNote(
                envelope: envelope,
                masterKeyBytes: masterKey,
                noteId: change.id,
              );

              final localNote = await database.getNoteWithTags(change.id);
              if (localNote != null &&
                  change.revision <= localNote.note.serverRevision) {
                // Already incorporated revision (e.g. via push auto-merge)
                continue;
              }

              if (localNote != null && localNote.note.isDirty) {
                // Colliding local edit while pulling!
                final basePlaintext = await _fetchBasePlaintext(
                    change.id, localNote.note.serverRevision, masterKey);
                final localPlaintext = NotePlaintext(
                  title: localNote.note.title,
                  body: localNote.note.content,
                  tags: localNote.tagNames,
                );

                final mergeRes = conflictResolver.merge3Way(
                  base: basePlaintext,
                  local: localPlaintext,
                  remote: decrypted,
                  localIsDeleted: localNote.note.isTrashed,
                  remoteIsDeleted: false,
                );

                if (mergeRes.isClean) {
                  await conflictResolver.applyAutoMerge(
                    noteId: change.id,
                    mergedPlaintext: mergeRes.mergedPlaintext,
                    baseRevision: localNote.note.serverRevision,
                    localRevision: localNote.note.serverRevision,
                    remoteRevision: change.revision,
                    updatedAt: change.updatedAt,
                  );
                } else {
                  const uuid = Uuid();
                  final conflict = SyncConflict(
                    id: uuid.v4(),
                    noteId: change.id,
                    baseRevision: localNote.note.serverRevision,
                    localRevision: localNote.note.serverRevision,
                    remoteRevision: change.revision,
                    conflictType: mergeRes.conflictType ?? ConflictType.content,
                    state: ConflictState.manualRequired,
                    createdAt: DateTime.now(),
                    basePlaintext: basePlaintext,
                    localPlaintext: localPlaintext,
                    remotePlaintext: decrypted,
                    localIsDeleted: localNote.note.isTrashed,
                    remoteIsDeleted: false,
                    conflictRegions: mergeRes.conflictRegions,
                    resolvedTitle: mergeRes.mergedPlaintext.title,
                    resolvedContent: mergeRes.mergedPlaintext.body,
                    resolvedTags: mergeRes.mergedPlaintext.tags,
                    explanation: mergeRes.explanation,
                  );
                  await database.saveConflict(
                    id: conflict.id,
                    noteId: conflict.noteId,
                    baseRevision: conflict.baseRevision,
                    localRevision: conflict.localRevision,
                    remoteRevision: conflict.remoteRevision,
                    conflictType: conflict.conflictType.name,
                    state: conflict.state.name,
                    createdAt: conflict.createdAt,
                    dataJson: conflict.toDataJson(),
                  );
                }
              } else {
                await database.saveNote(
                  id: change.id,
                  title: decrypted.title,
                  content: decrypted.body,
                  createdAt: change.createdAt,
                  updatedAt: change.updatedAt,
                  isPinned: change.pinned,
                  isArchived: change.archived,
                  isTrashed: change.trashed,
                  deletedAt: change.deletedAt,
                  tags: decrypted.tags,
                  serverRevision: change.revision,
                  isDirty: false,
                  syncedAt: DateTime.now(),
                );
              }

              // Pre-fetch metadata for any attachments referenced in pulled note
              final assetMatches = RegExp(
                r'qp://asset/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
              ).allMatches(decrypted.body);

              for (final match in assetMatches) {
                final assetId = match.group(1);
                if (assetId != null) {
                  final localAtt = await database.getAttachment(assetId);
                  if (localAtt == null || localAtt.cloudUrl == null || localAtt.cloudUrl!.isEmpty) {
                    try {
                      final remoteMeta = await apiClient.getAttachmentMetadata(assetId);
                      if (remoteMeta != null) {
                        await database.saveAttachment(
                          id: remoteMeta.id,
                          noteId: remoteMeta.noteId,
                          createdAt: remoteMeta.createdAt,
                          updatedAt: remoteMeta.updatedAt,
                          mimeType: remoteMeta.mimeType,
                          byteSize: remoteMeta.byteSize,
                          width: remoteMeta.width,
                          height: remoteMeta.height,
                          sha256: remoteMeta.sha256,
                          encryptionKeyVersion: remoteMeta.encryptionKeyVersion,
                          serverRevision: remoteMeta.serverRevision,
                          isDirty: false,
                          isDeleted: remoteMeta.isDeleted,
                          deletedAt: remoteMeta.deletedAt,
                          uploadState: 'synced',
                          cloudPublicId: remoteMeta.cloudPublicId,
                          cloudUrl: remoteMeta.cloudUrl,
                        );
                      }
                    } catch (attErr) {
                      debugPrint('Failed to prefetch metadata for attachment $assetId: $attErr');
                    }
                  }
                }
              }

              // Pre-fetch metadata for any scanned documents referenced in pulled note
              final docMatches = RegExp(
                r'qp://document/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
              ).allMatches(decrypted.body);

              for (final match in docMatches) {
                final docId = match.group(1);
                if (docId != null) {
                  final localDoc = await database.getDocument(docId);
                  if (localDoc == null || localDoc.cloudUrl == null || localDoc.cloudUrl!.isEmpty) {
                    try {
                      final remoteMeta = await apiClient.getDocumentMetadata(docId);
                      if (remoteMeta != null) {
                        await database.saveDocument(
                          id: remoteMeta.id,
                          noteId: remoteMeta.noteId,
                          title: remoteMeta.title,
                          createdAt: remoteMeta.createdAt,
                          updatedAt: remoteMeta.updatedAt,
                          mimeType: remoteMeta.mimeType,
                          byteSize: remoteMeta.byteSize,
                          pageCount: remoteMeta.pageCount,
                          sha256: remoteMeta.sha256,
                          encryptionKeyVersion: remoteMeta.encryptionKeyVersion,
                          serverRevision: remoteMeta.serverRevision,
                          isDirty: false,
                          isDeleted: remoteMeta.isDeleted,
                          deletedAt: remoteMeta.deletedAt,
                          uploadState: 'synced',
                          cloudPublicId: remoteMeta.cloudPublicId,
                          cloudUrl: remoteMeta.cloudUrl,
                        );
                      }
                    } catch (docErr) {
                      debugPrint('Failed to prefetch metadata for document $docId: $docErr');
                    }
                  }
                }
              }
            } catch (decErr) {
              // Log or skip malformed payload without halting sync loop
              debugPrint('Failed to decrypt pulled note ${change.id}: $decErr');
            }
          }
        }

        currentCursor = pullResponse.cursor;
        await database.setSyncMetadata('sync_cursor', currentCursor.toString());
        hasMore = pullResponse.hasMore;
      }

      // 4. NOTE VERSION SYNC PHASE
      // 4a. Push dirty note versions
      final dirtyVersions = await database.getDirtyNoteVersions();
      if (dirtyVersions.isNotEmpty) {
        final versionPayloads = <NoteVersionSyncPayload>[];
        for (final v in dirtyVersions) {
          List<String> tags = [];
          try {
            final decoded = jsonDecode(v.tagsJson);
            if (decoded is List) {
              tags = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}

          final plaintext = NotePlaintext(
            title: v.title,
            body: v.content,
            tags: tags,
          );
          final envelope = await cryptoService.encryptNote(
            plaintext: plaintext,
            masterKeyBytes: masterKey,
            noteId: v.noteId,
            keyVersion: 1,
          );

          versionPayloads.add(NoteVersionSyncPayload(
            id: v.id,
            noteId: v.noteId,
            versionNumber: v.versionNumber,
            contentCiphertext: envelope.ciphertext,
            contentNonce: envelope.nonce,
            charCount: v.charCount,
            wordCount: v.wordCount,
            deltaSummary: v.deltaSummary,
            createdAt: v.createdAt,
          ));
        }

        if (versionPayloads.isNotEmpty) {
          const versionBatchSize = 100;
          for (var i = 0; i < versionPayloads.length; i += versionBatchSize) {
            final end = (i + versionBatchSize < versionPayloads.length)
                ? i + versionBatchSize
                : versionPayloads.length;
            final batch = versionPayloads.sublist(i, end);

            final vPushRes = await apiClient.pushVersions(versions: batch);
            for (final res in vPushRes.results) {
              await database.markNoteVersionSynced(
                id: res.id,
                revision: res.revision,
                syncedAt: DateTime.now(),
              );
            }
          }
        }
      }

      // 4b. Pull remote note versions
      final vCursorStr = await database.getSyncMetadata('version_sync_cursor');
      var currentVCursor = int.tryParse(vCursorStr ?? '0') ?? 0;
      var hasMoreVersions = true;

      while (hasMoreVersions) {
        try {
          final vPullRes = await apiClient.pullVersions(cursor: currentVCursor, limit: 50);
          for (final change in vPullRes.changes) {
            try {
              final envelope = EncryptedEnvelope(
                version: 1,
                algorithm: 'xchacha20-poly1305',
                keyVersion: 1,
                nonce: change.contentNonce,
                ciphertext: change.contentCiphertext,
              );

              final decrypted = await cryptoService.decryptNote(
                envelope: envelope,
                masterKeyBytes: masterKey,
                noteId: change.noteId,
              );

              await database.saveNoteVersion(
                id: change.id,
                noteId: change.noteId,
                versionNumber: change.versionNumber,
                title: decrypted.title,
                content: decrypted.body,
                tagsJson: jsonEncode(decrypted.tags),
                createdAt: change.createdAt,
                charCount: change.charCount,
                wordCount: change.wordCount,
                deltaSummary: change.deltaSummary,
                serverRevision: change.revision,
                isDirty: false,
                syncedAt: DateTime.now(),
              );
            } catch (vDecErr) {
              debugPrint('Failed to decrypt pulled version ${change.id}: $vDecErr');
            }
          }
          currentVCursor = vPullRes.cursor;
          await database.setSyncMetadata('version_sync_cursor', currentVCursor.toString());
          hasMoreVersions = vPullRes.hasMore;
        } catch (vPullErr) {
          debugPrint('Note versions pull error: $vPullErr');
          hasMoreVersions = false;
        }
      }

      // 5. ATTACHMENT & DOCUMENT SYNC: Upload any pending encrypted attachments/documents to Cloudinary
      var attachmentsUploaded = 0;
      var attachmentsFailed = 0;
      final attachmentErrors = <String>[];

      if (attachmentSyncService != null) {
        final attResult = await attachmentSyncService!.syncPendingAttachments();
        attachmentsUploaded = attResult.uploadedCount;
        attachmentsFailed = attResult.failedCount;
        attachmentErrors.addAll(attResult.errors);
      }

      if (documentSyncService != null) {
        final docResult = await documentSyncService!.syncPendingDocuments();
        attachmentsUploaded += docResult.uploadedCount;
        attachmentsFailed += docResult.failedCount;
        attachmentErrors.addAll(docResult.errors);
      }

      // 6. REFERENCE PROJECTIONS SYNC: Send active and trashed resource references to server
      try {
        final allNotes = await database.getAllNotesRaw();
        final references = <SyncReferenceItem>[];
        for (final n in allNotes) {
          final content = n.content;
          final assetMatches = RegExp(
            r'qp://asset/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
          ).allMatches(content);
          for (final m in assetMatches) {
            final id = m.group(1);
            if (id != null) {
              references.add(SyncReferenceItem(
                resourceType: 'attachment',
                resourceId: id,
                noteId: n.id,
              ));
            }
          }

          final docMatches = RegExp(
            r'qp://document/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
          ).allMatches(content);
          for (final m in docMatches) {
            final id = m.group(1);
            if (id != null) {
              references.add(SyncReferenceItem(
                resourceType: 'document',
                resourceId: id,
                noteId: n.id,
              ));
            }
          }
        }

        if (references.isNotEmpty) {
          await apiClient.syncReferences(references: references);
        }
      } catch (refErr) {
        debugPrint('Reference projection sync error: $refErr');
      }

      final pendingConflicts = await database.getPendingConflictsCount();
      final hasActiveConflicts = pendingConflicts > 0;

      if (attachmentsFailed > 0) {
        final errorMsg = attachmentErrors.isNotEmpty
            ? attachmentErrors.first
            : 'Failed to upload $attachmentsFailed file(s) to Cloudinary';
        _updateState(SyncState(
          status: hasActiveConflicts ? SyncStatus.conflict : SyncStatus.syncError,
          lastSyncedAt: DateTime.now(),
          pendingCount: 0,
          conflictsCount: pendingConflicts,
          attachmentsSynced: attachmentsUploaded,
          attachmentsFailed: attachmentsFailed,
          errorMessage: errorMsg,
        ));
      } else {
        _updateState(SyncState(
          status: hasActiveConflicts ? SyncStatus.conflict : SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          pendingCount: 0,
          conflictsCount: pendingConflicts,
          attachmentsSynced: attachmentsUploaded,
          attachmentsFailed: 0,
          errorMessage: null,
        ));
      }
    } catch (e) {
      final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final isOffline = errStr.contains('SocketException') ||
          errStr.contains('ClientException') ||
          errStr.contains('Network is unreachable') ||
          errStr.contains('Connection refused');

      final pendingConflicts = await database.getPendingConflictsCount();

      _updateState(_state.copyWith(
        status: isOffline
            ? SyncStatus.offline
            : (pendingConflicts > 0 ? SyncStatus.conflict : SyncStatus.syncError),
        conflictsCount: pendingConflicts,
        errorMessage: errStr,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processPushConflicts(
    List<ConflictItem> conflicts,
    Uint8List masterKey,
  ) async {
    for (final c in conflicts) {
      final noteId = c.noteId ?? c.id;

      // 1. Get or fetch server head
      ServerHeadSyncPayload? serverHead = c.serverHead;
      if (serverHead == null) {
        try {
          final remoteItem = await apiClient.getRemoteNote(noteId: noteId);
          if (remoteItem != null) {
            serverHead = ServerHeadSyncPayload(
              revision: remoteItem.revision,
              contentCiphertext: remoteItem.contentCiphertext,
              contentNonce: remoteItem.contentNonce,
              contentVersion: remoteItem.contentVersion,
              encryptionKeyVersion: remoteItem.encryptionKeyVersion,
              isDeleted: remoteItem.isDeleted,
              deletedAt: remoteItem.deletedAt,
              archived: remoteItem.archived,
              trashed: remoteItem.trashed,
              pinned: remoteItem.pinned,
              folderId: remoteItem.folderId,
              sortOrder: remoteItem.sortOrder,
              createdAt: remoteItem.createdAt,
              updatedAt: remoteItem.updatedAt,
            );
          }
        } catch (e) {
          debugPrint('Failed to fetch server head for note $noteId: $e');
        }
      }

      if (serverHead == null) continue;

      // 2. Decrypt remote head
      NotePlaintext remotePlaintext;
      if (serverHead.isDeleted) {
        remotePlaintext = const NotePlaintext(title: '', body: '', tags: []);
      } else {
        try {
          final envelope = EncryptedEnvelope(
            version: serverHead.contentVersion,
            algorithm: 'xchacha20-poly1305',
            keyVersion: serverHead.encryptionKeyVersion,
            nonce: serverHead.contentNonce,
            ciphertext: serverHead.contentCiphertext,
          );
          remotePlaintext = await cryptoService.decryptNote(
            envelope: envelope,
            masterKeyBytes: masterKey,
            noteId: noteId,
          );
        } catch (e) {
          debugPrint('Failed to decrypt remote head for $noteId: $e');
          continue;
        }
      }

      // 3. Get local note
      final localNote = await database.getNoteWithTags(noteId);
      final localPlaintext = localNote != null
          ? NotePlaintext(
              title: localNote.note.title,
              body: localNote.note.content,
              tags: localNote.tagNames,
            )
          : const NotePlaintext(title: '', body: '', tags: []);
      final localIsDeleted = localNote == null || localNote.note.isTrashed;

      // 4. Fetch ancestor
      final basePlaintext =
          await _fetchBasePlaintext(noteId, c.baseRevision, masterKey);

      // 5. 3-way merge
      final mergeResult = conflictResolver.merge3Way(
        base: basePlaintext,
        local: localPlaintext,
        remote: remotePlaintext,
        localIsDeleted: localIsDeleted,
        remoteIsDeleted: serverHead.isDeleted,
      );

      if (mergeResult.isClean) {
        if (mergeResult.isDeleted) {
          await database.deletePermanently(noteId, enqueueSync: false);
        } else {
          await conflictResolver.applyAutoMerge(
            noteId: noteId,
            mergedPlaintext: mergeResult.mergedPlaintext,
            baseRevision: c.baseRevision ?? 0,
            localRevision: localNote?.note.serverRevision ?? 0,
            remoteRevision: serverHead.revision,
            updatedAt: DateTime.now(),
          );
        }
      } else {
        // Manual conflict required
        const uuid = Uuid();
        final conflict = SyncConflict(
          id: uuid.v4(),
          noteId: noteId,
          baseRevision: c.baseRevision ?? 0,
          localRevision: localNote?.note.serverRevision ?? 0,
          remoteRevision: serverHead.revision,
          conflictType: mergeResult.conflictType ?? ConflictType.content,
          state: ConflictState.manualRequired,
          createdAt: DateTime.now(),
          basePlaintext: basePlaintext,
          localPlaintext: localPlaintext,
          remotePlaintext: remotePlaintext,
          localIsDeleted: localIsDeleted,
          remoteIsDeleted: serverHead.isDeleted,
          conflictRegions: mergeResult.conflictRegions,
          resolvedTitle: mergeResult.mergedPlaintext.title,
          resolvedContent: mergeResult.mergedPlaintext.body,
          resolvedTags: mergeResult.mergedPlaintext.tags,
          explanation: mergeResult.explanation,
        );

        await database.saveConflict(
          id: conflict.id,
          noteId: conflict.noteId,
          baseRevision: conflict.baseRevision,
          localRevision: conflict.localRevision,
          remoteRevision: conflict.remoteRevision,
          conflictType: conflict.conflictType.name,
          state: conflict.state.name,
          createdAt: conflict.createdAt,
          dataJson: conflict.toDataJson(),
        );

        // Temporarily mark note not dirty so it does not block other notes or spam sync
        if (localNote != null) {
          await database.saveNote(
            id: noteId,
            title: localNote.note.title,
            content: localNote.note.content,
            createdAt: localNote.note.createdAt,
            updatedAt: localNote.note.updatedAt,
            isPinned: localNote.note.isPinned,
            isArchived: localNote.note.isArchived,
            isTrashed: localNote.note.isTrashed,
            deletedAt: localNote.note.deletedAt,
            tags: localNote.tagNames,
            serverRevision: localNote.note.serverRevision,
            isDirty: false,
          );
        }
      }
    }
  }

  Future<NotePlaintext?> _fetchBasePlaintext(
    String noteId,
    int? baseRevision,
    Uint8List masterKey,
  ) async {
    if (baseRevision == null || baseRevision <= 0) return null;

    // 1. Search local note version history
    try {
      final versions = await database.getNoteVersions(noteId, limit: 50);
      for (final v in versions) {
        if (v.serverRevision == baseRevision) {
          List<String> tags = [];
          try {
            final decoded = jsonDecode(v.tagsJson);
            if (decoded is List) {
              tags = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
          return NotePlaintext(title: v.title, body: v.content, tags: tags);
        }
      }
    } catch (e) {
      debugPrint('Error looking up local version ancestor: $e');
    }

    // 2. Query remote historical revision
    try {
      final remoteRev = await apiClient.getHistoricalRevision(
        noteId: noteId,
        revision: baseRevision,
      );
      if (remoteRev != null && remoteRev.contentCiphertext.isNotEmpty) {
        final envelope = EncryptedEnvelope(
          version: remoteRev.contentVersion,
          algorithm: 'xchacha20-poly1305',
          keyVersion: remoteRev.encryptionKeyVersion,
          nonce: remoteRev.contentNonce,
          ciphertext: remoteRev.contentCiphertext,
        );
        return await cryptoService.decryptNote(
          envelope: envelope,
          masterKeyBytes: masterKey,
          noteId: noteId,
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch historical ancestor for note $noteId rev $baseRevision: $e');
    }

    return null;
  }

  void dispose() {
    _syncDebouncer.dispose();
    _stateController.close();
  }
}
