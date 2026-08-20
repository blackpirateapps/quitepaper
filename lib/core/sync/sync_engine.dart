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
  }) {
    _init();
  }

  final AppDatabase database;
  final CryptoService cryptoService;
  final KeyManager keyManager;
  final AuthService authService;
  final SyncApiClient apiClient;
  final AttachmentSyncService? attachmentSyncService;
  final DocumentSyncService? documentSyncService;

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

      final pushPayloads = <NoteSyncPayload>[];

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

        pushPayloads.add(NoteSyncPayload(
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
        ));
      }

      for (final queueItem in pendingQueue) {
        if (queueItem.operation == 'delete') {
          pushPayloads.add(NoteSyncPayload(
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
          ));
        }
      }

      if (pushPayloads.isNotEmpty) {
        const uuid = Uuid();
        final idempotencyKey = 'push_${uuid.v4()}';

        final pushResponse = await apiClient.pushChanges(
          changes: pushPayloads,
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

        // Remove processed deletion queue entries
        if (pendingQueue.isNotEmpty) {
          await database
              .removeSyncQueueEntries(pendingQueue.map((q) => q.id).toList());
        }

        if (pushResponse.conflicts.isNotEmpty) {
          _updateState(_state.copyWith(
            conflictsCount: pushResponse.conflicts.length,
          ));
        }
      }

      // 3. PULL PHASE: Fetch server changes after cursor
      final cursorStr = await database.getSyncMetadata('sync_cursor');
      var currentCursor = int.tryParse(cursorStr ?? '0') ?? 0;
      var hasMore = true;

      while (hasMore) {
        final pullResponse =
            await apiClient.pullChanges(cursor: currentCursor, limit: 50);

        for (final change in pullResponse.changes) {
          if (change.isDeleted) {
            // Note was deleted on another device
            await database.deletePermanently(change.id, enqueueSync: false);
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
          final vPushRes = await apiClient.pushVersions(versions: versionPayloads);
          for (final res in vPushRes.results) {
            await database.markNoteVersionSynced(
              id: res.id,
              revision: res.revision,
              syncedAt: DateTime.now(),
            );
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

      if (attachmentsFailed > 0) {
        final errorMsg = attachmentErrors.isNotEmpty
            ? attachmentErrors.first
            : 'Failed to upload $attachmentsFailed file(s) to Cloudinary';
        _updateState(SyncState(
          status: SyncStatus.syncError,
          lastSyncedAt: DateTime.now(),
          pendingCount: 0,
          conflictsCount: _state.conflictsCount,
          attachmentsSynced: attachmentsUploaded,
          attachmentsFailed: attachmentsFailed,
          errorMessage: errorMsg,
        ));
      } else {
        _updateState(SyncState(
          status: SyncStatus.synced,
          lastSyncedAt: DateTime.now(),
          pendingCount: 0,
          conflictsCount: _state.conflictsCount,
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

      _updateState(_state.copyWith(
        status: isOffline ? SyncStatus.offline : SyncStatus.syncError,
        errorMessage: errStr,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _syncDebouncer.dispose();
    _stateController.close();
  }
}
