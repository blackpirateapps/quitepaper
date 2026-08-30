import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../attachments/attachment_storage.dart';
import '../crypto/crypto_service.dart';
import '../database/app_database.dart';
import '../documents/document_storage.dart';
import 'backup_models.dart';

class BackupService {
  BackupService({
    required this.database,
    required this.cryptoService,
    required this.sharedPreferences,
    AttachmentLocalStorage? storage,
    DocumentLocalStorage? documentStorage,
    FlutterSecureStorage? secureStorage,
    this.appVersion = '1.5.4',
  })  : _storage = storage ?? AttachmentLocalStorage(),
        _documentStorage = documentStorage ?? DocumentLocalStorage(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AppDatabase database;
  final CryptoService cryptoService;
  final SharedPreferences sharedPreferences;
  final AttachmentLocalStorage _storage;
  final DocumentLocalStorage _documentStorage;
  final FlutterSecureStorage _secureStorage;
  final String appVersion;

  static const _kAutoBackupEnabled = 'autobackup_enabled';
  static const _kAutoBackupFolderPath = 'autobackup_folder_path';
  static const _kAutoBackupRetentionCount = 'autobackup_retention_count';
  static const _kAutoBackupLastBackupAt = 'autobackup_last_backup_at';
  static const _kAutoBackupPasswordKey = 'autobackup_password';

  // ==========================================
  // AUTO-BACKUP CONFIGURATION
  // ==========================================

  AutoBackupConfig getAutoBackupConfig() {
    final enabled = sharedPreferences.getBool(_kAutoBackupEnabled) ?? false;
    final folderPath = sharedPreferences.getString(_kAutoBackupFolderPath);
    final retentionCount =
        sharedPreferences.getInt(_kAutoBackupRetentionCount) ?? 5;
    final lastStr = sharedPreferences.getString(_kAutoBackupLastBackupAt);
    final lastBackupAt =
        lastStr != null ? DateTime.tryParse(lastStr) : null;
    final hasPassword =
        sharedPreferences.getBool('$_kAutoBackupEnabled:has_pass') ?? false;

    return AutoBackupConfig(
      enabled: enabled,
      folderPath: folderPath,
      retentionCount: retentionCount,
      lastBackupAt: lastBackupAt,
      hasPassword: hasPassword,
    );
  }

  Future<void> updateAutoBackupConfig(AutoBackupConfig config) async {
    await sharedPreferences.setBool(_kAutoBackupEnabled, config.enabled);
    if (config.folderPath != null) {
      await sharedPreferences.setString(
          _kAutoBackupFolderPath, config.folderPath!);
    } else {
      await sharedPreferences.remove(_kAutoBackupFolderPath);
    }
    await sharedPreferences.setInt(
        _kAutoBackupRetentionCount, config.retentionCount);
    if (config.lastBackupAt != null) {
      await sharedPreferences.setString(
        _kAutoBackupLastBackupAt,
        config.lastBackupAt!.toIso8601String(),
      );
    }
  }

  Future<void> setAutoBackupPassword(String password) async {
    await _secureStorage.write(key: _kAutoBackupPasswordKey, value: password);
    await sharedPreferences.setBool('$_kAutoBackupEnabled:has_pass', true);
  }

  Future<void> clearAutoBackupPassword() async {
    await _secureStorage.delete(key: _kAutoBackupPasswordKey);
    await sharedPreferences.setBool('$_kAutoBackupEnabled:has_pass', false);
  }

  Future<String?> getAutoBackupPassword() async {
    return _secureStorage.read(key: _kAutoBackupPasswordKey);
  }

  // ==========================================
  // BACKUP GENERATION
  // ==========================================

  /// Generates full in-memory snapshot payload of the database
  Future<BackupPayload> generateBackupPayload({
    bool includeTrash = true,
    bool includeArchived = true,
  }) async {
    final allEntities = await database.select(database.notesTable).get();

    final filtered = allEntities.where((n) {
      if (!includeTrash && n.isTrashed) return false;
      if (!includeArchived && n.isArchived) return false;
      return true;
    }).toList();

    final noteIds = filtered.map((n) => n.id).toList();

    // Query tags for notes
    final tagsByNoteId = <String, List<String>>{};
    if (noteIds.isNotEmpty) {
      final tagQuery = database.select(database.tagsTable).join([
        innerJoin(
          database.noteTagsTable,
          database.noteTagsTable.tagId.equalsExp(database.tagsTable.id),
        ),
      ])..where(database.noteTagsTable.noteId.isIn(noteIds));

      final rows = await tagQuery.get();
      for (final row in rows) {
        final noteId = row.readTable(database.noteTagsTable).noteId;
        final tagName = row.readTable(database.tagsTable).name;
        tagsByNoteId.putIfAbsent(noteId, () => []).add(tagName);
      }
    }

    final backupNotes = filtered.map((n) {
      return BackupNote(
        id: n.id,
        title: n.title,
        content: n.content,
        tags: tagsByNoteId[n.id] ?? [],
        isPinned: n.isPinned,
        isArchived: n.isArchived,
        isTrashed: n.isTrashed,
        createdAt: n.createdAt,
        updatedAt: n.updatedAt,
        deletedAt: n.deletedAt,
      );
    }).toList();

    final allTagNames = await database.getAllTagNames();

    // Query attachments for included notes
    final allAttachments = await database.getAllAttachments();
    final filteredAttachments = allAttachments
        .where((a) => !a.isDeleted && (a.noteId == null || noteIds.contains(a.noteId)))
        .toList();

    final backupAttachments = <BackupAttachment>[];
    for (final att in filteredAttachments) {
      final encryptedBytes = await _storage.readEncryptedBytes(
        attachmentId: att.id,
        variant: 'original',
        localPath: att.localPath,
      );

      final ocrPageRows = await database.getAttachmentOcrPages(att.id);
      final backupOcrPages = ocrPageRows.map((row) {
        return BackupAttachmentOcrPage(
          attachmentId: row.attachmentId,
          pageNumber: row.pageNumber,
          encryptedPayload: row.encryptedPayload,
          ocrSchemaVersion: row.ocrSchemaVersion,
          ocrEngine: row.ocrEngine,
          ocrEngineVersion: row.ocrEngineVersion,
          language: row.language,
          processedAt: row.processedAt,
        );
      }).toList();

      backupAttachments.add(BackupAttachment(
        id: att.id,
        noteId: att.noteId,
        fileName: att.fileName,
        kind: att.kind,
        createdAt: att.createdAt,
        updatedAt: att.updatedAt,
        mimeType: att.mimeType,
        byteSize: att.byteSize,
        width: att.width,
        height: att.height,
        sha256: att.sha256,
        encryptionKeyVersion: att.encryptionKeyVersion,
        encryptedPayloadBase64:
            encryptedBytes != null ? base64Encode(encryptedBytes) : null,
        ocrState: att.ocrState,
        ocrLanguage: att.ocrLanguage,
        ocrPages: backupOcrPages,
      ));
    }

    // Query scanned/imported documents for included notes
    final allDocuments = await database.getAllDocuments();
    final filteredDocuments = allDocuments
        .where((d) => !d.isDeleted && (d.noteId == null || noteIds.contains(d.noteId)))
        .toList();

    final backupDocuments = <BackupDocument>[];
    for (final doc in filteredDocuments) {
      final encryptedBytes = await _documentStorage.readEncryptedBytes(
        documentId: doc.id,
        localPath: doc.localPath,
      );

      final ocrPageRows = await database.getDocumentOcrPages(doc.id);
      final backupOcrPages = ocrPageRows.map((row) {
        return BackupDocumentOcrPage(
          documentId: row.documentId,
          pageNumber: row.pageNumber,
          encryptedPayload: row.encryptedPayload,
          ocrSchemaVersion: row.ocrSchemaVersion,
          ocrEngine: row.ocrEngine,
          ocrEngineVersion: row.ocrEngineVersion,
          language: row.language,
          processedAt: row.processedAt,
        );
      }).toList();

      backupDocuments.add(BackupDocument(
        id: doc.id,
        noteId: doc.noteId,
        title: doc.title,
        source: doc.source,
        createdAt: doc.createdAt,
        updatedAt: doc.updatedAt,
        mimeType: doc.mimeType,
        byteSize: doc.byteSize,
        pageCount: doc.pageCount,
        sha256: doc.sha256,
        encryptionKeyVersion: doc.encryptionKeyVersion,
        encryptedPayloadBase64:
            encryptedBytes != null ? base64Encode(encryptedBytes) : null,
        ocrState: doc.ocrState,
        ocrLanguage: doc.ocrLanguage,
        ocrPages: backupOcrPages,
      ));
    }

    final activeCount =
        backupNotes.where((n) => !n.isArchived && !n.isTrashed).length;
    final archivedCount = backupNotes.where((n) => n.isArchived).length;
    final trashedCount = backupNotes.where((n) => n.isTrashed).length;
    final pinnedCount =
        backupNotes.where((n) => n.isPinned && !n.isTrashed).length;

    final manifest = BackupManifest(
      format: 'quietpaper:backup:v1',
      version: 1,
      appVersion: appVersion,
      createdAt: DateTime.now(),
      isEncrypted: false,
      totalNotes: backupNotes.length,
      activeNotes: activeCount,
      archivedNotes: archivedCount,
      trashedNotes: trashedCount,
      pinnedNotes: pinnedCount,
      totalTags: allTagNames.length,
      totalAttachments: backupAttachments.length,
      totalDocuments: backupDocuments.length,
    );

    return BackupPayload(
      manifest: manifest,
      notes: backupNotes,
      tags: allTagNames,
      attachments: backupAttachments,
      documents: backupDocuments,
    );
  }

  /// Generates the serialized String content (either formatted JSON or Argon2id encrypted envelope JSON)
  Future<String> generateBackupString({
    String? password,
    bool includeTrash = true,
    bool includeArchived = true,
  }) async {
    final payload = await generateBackupPayload(
      includeTrash: includeTrash,
      includeArchived: includeArchived,
    );

    if (password != null && password.trim().isNotEmpty) {
      // Encrypted backup with Argon2id + XChaCha20-Poly1305
      final saltBytes = cryptoService.generateRandomBytes(16);
      final derivedKey = await cryptoService.deriveKeyFromPassword(
        password: password.trim(),
        salt: saltBytes,
        parameters: KdfParameters.standard,
      );

      final payloadJson = jsonEncode(payload.toJson());
      final payloadBytes = utf8.encode(payloadJson);
      final nonceBytes = cryptoService.generateRandomBytes(24);
      final aad = utf8.encode('quietpaper:backup:v1');

      final ciphertextBytes = await cryptoService.encryptRawBytes(
        plaintextBytes: payloadBytes,
        secretKey: derivedKey,
        nonce: nonceBytes,
        associatedData: aad,
      );

      final encryptedManifest = BackupManifest(
        format: payload.manifest.format,
        version: payload.manifest.version,
        appVersion: payload.manifest.appVersion,
        createdAt: payload.manifest.createdAt,
        isEncrypted: true,
        totalNotes: payload.manifest.totalNotes,
        activeNotes: payload.manifest.activeNotes,
        archivedNotes: payload.manifest.archivedNotes,
        trashedNotes: payload.manifest.trashedNotes,
        pinnedNotes: payload.manifest.pinnedNotes,
        totalTags: payload.manifest.totalTags,
        totalAttachments: payload.manifest.totalAttachments,
      );

      final envelope = EncryptedBackupEnvelope(
        kdfSalt: base64Encode(saltBytes),
        kdfParameters: KdfParameters.standard,
        nonce: base64Encode(nonceBytes),
        ciphertext: base64Encode(ciphertextBytes),
        manifestSummary: encryptedManifest,
      );

      return jsonEncode(envelope.toJson());
    } else {
      // Unencrypted backup
      return const JsonEncoder.withIndent('  ').convert(payload.toJson());
    }
  }

  /// Generates raw UTF-8 bytes of the backup content for SAF / file picker saving
  Future<Uint8List> generateBackupBytes({
    String? password,
    bool includeTrash = true,
    bool includeArchived = true,
  }) async {
    final str = await generateBackupString(
      password: password,
      includeTrash: includeTrash,
      includeArchived: includeArchived,
    );
    return Uint8List.fromList(utf8.encode(str));
  }

  /// Writes a `.qpbackup` file into the target directory (optionally encrypted)
  Future<File> createBackupFile({
    required String directoryPath,
    String? customFileName,
    String? password,
    bool includeTrash = true,
    bool includeArchived = true,
    bool isAutoBackup = false,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd_HHmmss').format(now);
    final prefix = isAutoBackup ? 'quietpaper_autobackup' : 'quietpaper_backup';
    final fileName = customFileName != null && customFileName.isNotEmpty
        ? (customFileName.endsWith('.qpbackup')
            ? customFileName
            : '$customFileName.qpbackup')
        : '${prefix}_$dateStr.qpbackup';

    final targetDir = Directory(directoryPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File('${targetDir.path}/$fileName');
    final content = await generateBackupString(
      password: password,
      includeTrash: includeTrash,
      includeArchived: includeArchived,
    );

    await targetFile.writeAsString(content, flush: true);
    return targetFile;
  }

  // ==========================================
  // BACKUP VALIDATION & DECRYPTION
  // ==========================================

  /// Validates a `.qpbackup` file and decrypts it if password is provided
  Future<BackupValidationResult> validateBackupFile(
    File file, {
    String? password,
  }) async {
    try {
      if (!await file.exists()) {
        return const BackupValidationResult(
          isValid: false,
          isEncrypted: false,
          errorMessage: 'Selected backup file does not exist.',
        );
      }

      final content = await file.readAsString();
      return await validateBackupString(content, password: password);
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        isEncrypted: false,
        errorMessage: 'Failed to read backup file: $e',
      );
    }
  }

  /// Validates backup string content directly and decrypts it if password is provided
  Future<BackupValidationResult> validateBackupString(
    String content, {
    String? password,
  }) async {
    try {
      final dynamic decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          isEncrypted: false,
          errorMessage: 'Invalid JSON backup structure.',
        );
      }

      final format = decoded['format'] as String? ?? '';

      // 1. Encrypted Envelope
      if (format == 'quietpaper:encrypted-backup:v1' ||
          decoded.containsKey('ciphertext')) {
        final envelope = EncryptedBackupEnvelope.fromJson(decoded);

        if (password == null || password.isEmpty) {
          return BackupValidationResult(
            isValid: true,
            isEncrypted: true,
            manifest: envelope.manifestSummary,
          );
        }

        // Attempt decryption with supplied password
        try {
          final saltBytes = base64Decode(envelope.kdfSalt);
          final nonceBytes = base64Decode(envelope.nonce);
          final ciphertextBytes = base64Decode(envelope.ciphertext);

          final derivedKey = await cryptoService.deriveKeyFromPassword(
            password: password,
            salt: saltBytes,
            parameters: envelope.kdfParameters,
          );

          final aad = utf8.encode('quietpaper:backup:v1');
          final decryptedBytes = await cryptoService.decryptRawBytes(
            combinedCiphertext: ciphertextBytes,
            secretKey: derivedKey,
            nonce: nonceBytes,
            associatedData: aad,
          );

          final decryptedJson = utf8.decode(decryptedBytes);
          final payload = BackupPayload.fromJson(
              jsonDecode(decryptedJson) as Map<String, dynamic>);

          return BackupValidationResult(
            isValid: true,
            isEncrypted: true,
            manifest: payload.manifest,
            payload: payload,
          );
        } catch (decErr) {
          return const BackupValidationResult(
            isValid: false,
            isEncrypted: true,
            errorMessage: 'Incorrect backup password or corrupted ciphertext.',
          );
        }
      }

      // 2. Unencrypted Backup Payload
      if (format == 'quietpaper:backup:v1' || decoded.containsKey('notes')) {
        final payload = BackupPayload.fromJson(decoded);
        return BackupValidationResult(
          isValid: true,
          isEncrypted: false,
          manifest: payload.manifest,
          payload: payload,
        );
      }

      return const BackupValidationResult(
        isValid: false,
        isEncrypted: false,
        errorMessage: 'Unrecognized backup file format.',
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        isEncrypted: false,
        errorMessage: 'Failed to read backup file: $e',
      );
    }
  }

  // ==========================================
  // RESTORE OPERATION
  // ==========================================

  /// Restores a valid BackupPayload into SQLite database
  Future<RestoreResult> restoreBackup(
    BackupPayload payload, {
    RestoreStrategy strategy = RestoreStrategy.merge,
  }) async {
    const uuid = Uuid();
    var totalRestored = 0;
    var totalUpdated = 0;
    var totalSkipped = 0;
    var totalConflicts = 0;

    await database.transaction(() async {
      // If strategy is replace, wipe current tables
      if (strategy == RestoreStrategy.replace) {
        await database.delete(database.noteTagsTable).go();
        await database.delete(database.notesTable).go();
        await database.delete(database.tagsTable).go();
      }

      for (final backupNote in payload.notes) {
        var noteIdToSave = backupNote.id;
        var titleToSave = backupNote.title;

        if (strategy == RestoreStrategy.merge) {
          final existing = await (database.select(database.notesTable)
                ..where((n) => n.id.equals(backupNote.id)))
              .getSingleOrNull();

          if (existing != null) {
            // Compare timestamps
            if (backupNote.updatedAt.isAfter(existing.updatedAt)) {
              // Update with newer backup version
              totalUpdated++;
            } else {
              // Local is newer or identical, skip
              totalSkipped++;
              continue;
            }
          } else {
            totalRestored++;
          }
        } else if (strategy == RestoreStrategy.keepBoth) {
          final existing = await (database.select(database.notesTable)
                ..where((n) => n.id.equals(backupNote.id)))
              .getSingleOrNull();

          if (existing != null) {
            noteIdToSave = uuid.v4();
            if (titleToSave.isNotEmpty) {
              titleToSave = '$titleToSave (Restored)';
            }
            totalConflicts++;
          } else {
            totalRestored++;
          }
        } else {
          // Replace strategy
          totalRestored++;
        }

        await database.saveNote(
          id: noteIdToSave,
          title: titleToSave,
          content: backupNote.content,
          createdAt: backupNote.createdAt,
          updatedAt: backupNote.updatedAt,
          isPinned: backupNote.isPinned,
          isArchived: backupNote.isArchived,
          isTrashed: backupNote.isTrashed,
          deletedAt: backupNote.deletedAt,
          tags: backupNote.tags,
          serverRevision: 0,
          isDirty: true,
          syncedAt: null,
        );
      }

      // Restore attachments if included in payload
      for (final backupAtt in payload.attachments) {
        String? localSavedPath;
        if (backupAtt.encryptedPayloadBase64 != null &&
            backupAtt.encryptedPayloadBase64!.isNotEmpty) {
          try {
            final encryptedBytes =
                base64Decode(backupAtt.encryptedPayloadBase64!);
            localSavedPath = await _storage.saveEncryptedBytes(
              attachmentId: backupAtt.id,
              encryptedBytes: encryptedBytes,
              variant: 'original',
            );
          } catch (_) {}
        }

        await database.saveAttachment(
          id: backupAtt.id,
          noteId: backupAtt.noteId,
          fileName: backupAtt.fileName,
          kind: backupAtt.kind,
          createdAt: backupAtt.createdAt,
          updatedAt: backupAtt.updatedAt,
          mimeType: backupAtt.mimeType,
          byteSize: backupAtt.byteSize,
          width: backupAtt.width,
          height: backupAtt.height,
          sha256: backupAtt.sha256,
          encryptionKeyVersion: backupAtt.encryptionKeyVersion,
          isDirty: true,
          isDeleted: false,
          serverRevision: 0,
          uploadState: 'upload_pending',
          localPath: localSavedPath,
          ocrState: backupAtt.ocrState,
          ocrLanguage: backupAtt.ocrLanguage,
        );

        // Restore Attachment OCR pages if present
        for (final ocrPage in backupAtt.ocrPages) {
          await database.saveAttachmentOcrPage(
            attachmentId: ocrPage.attachmentId,
            pageNumber: ocrPage.pageNumber,
            encryptedPayload: ocrPage.encryptedPayload,
            ocrSchemaVersion: ocrPage.ocrSchemaVersion,
            ocrEngine: ocrPage.ocrEngine,
            ocrEngineVersion: ocrPage.ocrEngineVersion,
            language: ocrPage.language,
            processedAt: ocrPage.processedAt,
          );
        }
      }

      // Restore scanned/imported documents if included in payload
      for (final backupDoc in payload.documents) {
        String? localSavedPath;
        if (backupDoc.encryptedPayloadBase64 != null &&
            backupDoc.encryptedPayloadBase64!.isNotEmpty) {
          try {
            final encryptedBytes =
                base64Decode(backupDoc.encryptedPayloadBase64!);
            localSavedPath = await _documentStorage.saveEncryptedBytes(
               documentId: backupDoc.id,
               encryptedBytes: encryptedBytes,
            );
          } catch (_) {}
        }

        await database.saveDocument(
          id: backupDoc.id,
          noteId: backupDoc.noteId,
          title: backupDoc.title,
          source: backupDoc.source,
          createdAt: backupDoc.createdAt,
          updatedAt: backupDoc.updatedAt,
          mimeType: backupDoc.mimeType,
          byteSize: backupDoc.byteSize,
          pageCount: backupDoc.pageCount,
          sha256: backupDoc.sha256,
          encryptionKeyVersion: backupDoc.encryptionKeyVersion,
          isDirty: true,
          isDeleted: false,
          serverRevision: 0,
          uploadState: 'upload_pending',
          localPath: localSavedPath,
          ocrState: backupDoc.ocrState,
          ocrLanguage: backupDoc.ocrLanguage,
        );

        // Restore OCR pages if present
        for (final ocrPage in backupDoc.ocrPages) {
          await database.saveDocumentOcrPage(
            documentId: ocrPage.documentId,
            pageNumber: ocrPage.pageNumber,
            encryptedPayload: ocrPage.encryptedPayload,
            ocrSchemaVersion: ocrPage.ocrSchemaVersion,
            ocrEngine: ocrPage.ocrEngine,
            ocrEngineVersion: ocrPage.ocrEngineVersion,
            language: ocrPage.language,
            processedAt: ocrPage.processedAt,
          );
        }
      }
    });

    final currentTags = await database.getAllTagNames();

    return RestoreResult(
      totalRestored: totalRestored,
      totalUpdated: totalUpdated,
      totalSkipped: totalSkipped,
      totalConflicts: totalConflicts,
      totalTagsCreated: currentTags.length,
      totalDocumentsRestored: payload.documents.length,
    );
  }

  // ==========================================
  // AUTOMATED ROLLING BACKUPS
  // ==========================================

  /// Performs an automated rolling backup if enabled and 24 hours have elapsed
  Future<File?> performAutoBackupIfDue() async {
    final config = getAutoBackupConfig();
    if (!config.enabled || config.folderPath == null || config.folderPath!.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    if (config.lastBackupAt != null) {
      final hoursSince = now.difference(config.lastBackupAt!).inHours;
      if (hoursSince < 24) {
        return null;
      }
    }

    final dir = Directory(config.folderPath!);
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {
        return null;
      }
    }

    String? autoPass;
    if (config.hasPassword) {
      autoPass = await getAutoBackupPassword();
    }

    try {
      final file = await createBackupFile(
        directoryPath: config.folderPath!,
        password: autoPass,
        isAutoBackup: true,
      );

      // Prune old rolling backups exceeding retention limit
      await pruneOldAutoBackups(dir, config.retentionCount);

      // Update last backup timestamp
      await updateAutoBackupConfig(config.copyWith(lastBackupAt: now));

      return file;
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
      return null;
    }
  }

  /// Prunes oldest auto-backup files exceeding the retention limit
  Future<int> pruneOldAutoBackups(Directory dir, int retentionCount) async {
    try {
      if (!await dir.exists()) return 0;

      final entities = await dir.list().toList();
      final autoBackups = <File>[];

      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.startsWith('quietpaper_autobackup_') &&
              name.endsWith('.qpbackup')) {
            autoBackups.add(entity);
          }
        }
      }

      if (autoBackups.length <= retentionCount) {
        return 0;
      }

      // Sort by modified time descending (newest first)
      autoBackups.sort((a, b) {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return bTime.compareTo(aTime);
      });

      var deletedCount = 0;
      for (var i = retentionCount; i < autoBackups.length; i++) {
        try {
          await autoBackups[i].delete();
          deletedCount++;
        } catch (_) {}
      }

      return deletedCount;
    } catch (e) {
      debugPrint('Failed to prune old auto backups: $e');
      return 0;
    }
  }
}
