import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/crypto/local_vault_key_migration.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/documents/annotations/annotation_models.dart';
import 'package:quitepaper/core/documents/annotations/annotation_service.dart';
import 'package:quitepaper/core/documents/document_crypto.dart';
import 'package:quitepaper/core/documents/document_storage.dart';
import 'package:quitepaper/core/ocr/ocr_crypto.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/email_import/application/email_parser.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import '../sync/sync_engine_test.dart' show InMemorySyncApiClient;

class _Storage extends FlutterSecureStorage {
  String? failWriteKey;
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == failWriteKey) throw StateError('Secure storage write failed');
    await super.write(key: key, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const journalKey = 'quietpaper_local_key_transition_v1';
  const masterKeyName = 'quietpaper_master_key_v1';
  const kdf = KdfParameters(memory: 1024, iterations: 1, parallelism: 1);
  late AppDatabase db;
  late Directory directory;
  late AttachmentLocalStorage attachments;
  late DocumentLocalStorage documents;
  late LocalVaultKeyMigration migration;
  late _Storage storage;
  late SecureKeyManager keys;
  late WrappedMasterKeyData remote;
  late Uint8List cloudKey;
  late Uint8List localKey;
  final crypto = DefaultCryptoService();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final cloud = SecureKeyManager(secureStorage: const FlutterSecureStorage());
    remote = await cloud.setupNewKeys(
      password: 'cloud-password',
      recoveryKey: 'cloud-recovery',
      kdfParameters: kdf,
    );
    cloudKey = Uint8List.fromList(cloud.getMasterKey());
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('qp-key-migration-');
    db = AppDatabase.memory();
    attachments = AttachmentLocalStorage(
      customBaseDirectory: Directory('${directory.path}/assets'),
    );
    documents = DocumentLocalStorage(
      customDocumentsDirectory: Directory('${directory.path}/documents'),
    );
    migration = LocalVaultKeyMigration(
      database: db,
      attachments: attachments,
      documents: documents,
      crypto: crypto,
    );
    storage = _Storage();
    keys = SecureKeyManager(
      secureStorage: storage,
      migrateLocalVault: migration.migrate,
    );
    await keys.ensureLocalKey();
    localKey = Uint8List.fromList(keys.getMasterKey());
  });

  tearDown(() async {
    await db.close();
    AttachmentLocalStorage.purgeAllMemoryCache();
    await directory.delete(recursive: true);
  });

  Future<AttachmentEntity> importFile([String name = 'local.txt']) async {
    final imported =
        await AttachmentService(
          database: db,
          keyManager: keys,
          storage: attachments,
        ).importGenericFileFromBytes(
          Uint8List.fromList(utf8.encode(name)),
          fileName: name,
        );
    return imported.attachment;
  }

  Future<void> unlock() => keys.unlockWithPassword(
    password: 'cloud-password',
    remoteWrappedKey: remote,
  );

  for (final recovery in [false, true]) {
    test(
      'unused offline key permits cloud sign-in with ${recovery ? 'recovery key' : 'password'}',
      () async {
        keys.lock();
        if (recovery) {
          await keys.unlockWithRecoveryKey(
            recoveryKey: 'cloud-recovery',
            remoteWrappedKey: remote,
          );
        } else {
          await unlock();
        }
        expect(keys.getMasterKey(), orderedEquals(cloudKey));
        expect(await storage.read(key: journalKey), isNull);
        final restarted = SecureKeyManager(
          secureStorage: storage,
          migrateLocalVault: migration.migrate,
        );
        await restarted.initialize();
        expect(restarted.getMasterKey(), orderedEquals(cloudKey));
        expect(
          (await restarted.getStoredWrappedKeyData())!.toJson(),
          remote.toJson(),
        );
      },
    );
  }

  test(
    'cloud sign-in preserves offline imported email sources and attachments',
    () async {
      final repository = DriftNotesRepository(db);
      final vault = AttachmentService(
        database: db,
        keyManager: keys,
        storage: attachments,
      );
      final service = EmailImportService(
        database: db,
        repository: repository,
        attachments: vault,
      );
      final message = const EmailParser().parseSync(
        File('test/email_import/fixtures/mixed.eml').readAsBytesSync(),
      );
      final note = await service.save(
        email: message,
        mode: EmailImportMode.editable,
        title: 'Offline mail',
      );
      final originalNotes = await db.select(db.notesTable).get();
      final originalAssets = await db.select(db.attachmentsTable).get();
      expect(originalAssets, isNotEmpty);
      final plaintext = <String, Uint8List>{};
      for (final asset in originalAssets) {
        plaintext[asset.id] = Uint8List.fromList(
          (await vault.resolveAsset(asset.id)).data!,
        );
      }

      final auth = MockAuthService();
      final api = InMemorySyncApiClient()..storedKey = remote;
      final engine = SyncEngine(
        database: db,
        cryptoService: crypto,
        keyManager: keys,
        authService: auth,
        apiClient: api,
      );
      addTearDown(engine.dispose);
      await auth.signInWithEmailAndPassword(
        'account@example.test',
        'account-password',
      );
      // Firebase identity alone must not upload using the device-only key.
      await engine.syncNow();
      expect(engine.state.status, SyncStatus.pendingSync);
      expect(api.serverNotes, isEmpty);

      await unlock();

      expect(keys.getMasterKey(), orderedEquals(cloudKey));
      expect(await db.select(db.notesTable).get(), originalNotes);
      expect(
        (await repository.getNoteById(note.id))!.importSources,
        isNotEmpty,
      );
      final freshDevice = AttachmentService(
        database: db,
        keyManager: keys,
        storage: attachments,
      );
      for (final asset in originalAssets) {
        expect(
          (await freshDevice.resolveAsset(asset.id)).data,
          orderedEquals(plaintext[asset.id]!),
        );
        final encrypted = await File(asset.localPath!).readAsBytes();
        await expectLater(
          AttachmentCrypto().decryptAttachment(
            encryptedEnvelopeBytes: encrypted,
            masterKeyBytes: localKey,
            attachmentId: asset.id,
          ),
          throwsA(isA<AttachmentDecryptionException>()),
        );
      }
      expect(await storage.read(key: journalKey), isNull);
      await engine.syncNow();
      expect(engine.state.status, SyncStatus.synced);
      expect(api.storedKey!.toJson(), remote.toJson());
      final pushed = api.serverNotes[note.id]!;
      final cloudPlaintext = await crypto.decryptNote(
        envelope: EncryptedEnvelope(
          version: 1,
          algorithm: 'xchacha20-poly1305',
          keyVersion: 1,
          nonce: pushed.contentNonce,
          ciphertext: pushed.contentCiphertext,
        ),
        masterKeyBytes: cloudKey,
        noteId: note.id,
      );
      expect(cloudPlaintext.title, 'Offline mail');
      expect(cloudPlaintext.importSources, note.importSources);
    },
  );

  test(
    'migrates PDFs, variants, OCR, annotations and keyed place aliases',
    () async {
      final now = DateTime.now();
      final asset = await importFile();
      final variant = await AttachmentCrypto().encryptAttachment(
        plaintextBytes: Uint8List.fromList([1, 2, 3]),
        masterKeyBytes: localKey,
        attachmentId: asset.id,
        variant: 'preview',
      );
      final variantPath = await attachments.saveEncryptedBytes(
        attachmentId: asset.id,
        encryptedBytes: variant,
        variant: 'preview',
      );
      await db.saveAttachmentVariant(
        id: 'variant',
        attachmentId: asset.id,
        variantType: 'preview',
        localPath: variantPath,
        createdAt: now,
      );
      final pdfBytes = Uint8List.fromList(utf8.encode('original PDF bytes'));
      final documentCrypto = DocumentCrypto();
      final pdf = await documentCrypto.encryptDocument(
        plaintextBytes: pdfBytes,
        masterKeyBytes: localKey,
        documentId: 'pdf',
      );
      final pdfPath = await documents.saveEncryptedBytes(
        documentId: 'pdf',
        encryptedBytes: pdf,
      );
      await documents.saveEncryptedAnnotatedBytes(
        documentId: 'pdf',
        encryptedBytes: pdf,
      );
      await db.saveDocument(
        id: 'pdf',
        createdAt: now,
        updatedAt: now,
        localPath: pdfPath,
      );
      final ocr = OcrCrypto();
      final ocrPlaintext = Uint8List.fromList(
        utf8.encode('{"text":"private OCR"}'),
      );
      for (final id in ['pdf', asset.id]) {
        final encrypted = await ocr.encryptRawOcrBytes(
          plaintextBytes: ocrPlaintext,
          masterKeyBytes: localKey,
          documentId: id,
        );
        if (id == 'pdf') {
          await db.saveDocumentOcrPage(
            documentId: id,
            pageNumber: 1,
            encryptedPayload: base64Encode(encrypted),
            processedAt: now,
          );
        } else {
          await db.saveAttachmentOcrPage(
            attachmentId: id,
            encryptedPayload: base64Encode(encrypted),
            processedAt: now,
          );
        }
      }
      final annotationService = DocumentAnnotationService(
        database: db,
        keyManager: keys,
      );
      await annotationService.savePage(
        documentId: 'pdf',
        pageIndex: 0,
        annotations: [
          const Annotation(
            id: 'comment',
            documentId: 'pdf',
            pageIndex: 0,
            type: AnnotationType.comment,
            geometry: AnnotationGeometry(),
            text: 'Keep this comment',
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        ],
      );
      final aliasId = crypto.computePlaceAliasId(
        matchKey: 'home',
        masterKeyBytes: localKey,
      );
      final alias = await crypto.encryptPlaceAliasPayload(
        plaintext: const PlaceAliasPlaintext(
          matchKey: 'home',
          canonicalKey: 'house',
          displayName: 'Home',
        ),
        masterKeyBytes: localKey,
        placeAliasId: aliasId,
      );
      await db.putLocalPlaceAlias(
        id: aliasId,
        contentCiphertext: alias.ciphertext,
        contentNonce: alias.nonce,
        contentVersion: alias.contentVersion,
        encryptionKeyVersion: alias.keyVersion,
      );

      await unlock();

      for (final path in [
        pdfPath,
        await documents.getEncryptedAnnotatedFilePath('pdf'),
      ]) {
        expect(
          await documentCrypto.decryptDocument(
            encryptedEnvelopeBytes: await File(path).readAsBytes(),
            masterKeyBytes: cloudKey,
            documentId: 'pdf',
          ),
          orderedEquals(pdfBytes),
        );
      }
      expect(
        await AttachmentCrypto().decryptAttachment(
          encryptedEnvelopeBytes: await File(variantPath).readAsBytes(),
          masterKeyBytes: cloudKey,
          attachmentId: asset.id,
          variant: 'preview',
        ),
        orderedEquals([1, 2, 3]),
      );
      final docOcr = (await db.select(db.documentOcrPagesTable).get()).single;
      final assetOcr =
          (await db.select(db.attachmentOcrPagesTable).get()).single;
      for (final entry in [
        (docOcr.encryptedPayload, 'pdf'),
        (assetOcr.encryptedPayload, asset.id),
      ]) {
        expect(
          await ocr.decryptRawOcrBytes(
            encryptedEnvelopeBytes: base64Decode(entry.$1),
            masterKeyBytes: cloudKey,
            documentId: entry.$2,
          ),
          orderedEquals(ocrPlaintext),
        );
      }
      expect(
        (await annotationService.loadPage('pdf', 0)).single.text,
        'Keep this comment',
      );
      final migratedAlias =
          (await db.select(db.placeAliasesTable).get()).single;
      expect(
        migratedAlias.id,
        crypto.computePlaceAliasId(matchKey: 'home', masterKeyBytes: cloudKey),
      );
      expect(migratedAlias.id, isNot(aliasId));
      expect(
        (await crypto.decryptPlaceAliasPayload(
          envelope: EncryptedEnvelope(
            version: migratedAlias.contentVersion,
            algorithm: 'xchacha20-poly1305',
            keyVersion: migratedAlias.encryptionKeyVersion,
            nonce: migratedAlias.contentNonce,
            ciphertext: migratedAlias.contentCiphertext,
          ),
          masterKeyBytes: cloudKey,
          placeAliasId: migratedAlias.id,
        )).displayName,
        'Home',
      );
    },
  );

  test(
    'wrong cloud password leaves local content and secure keys unchanged',
    () async {
      final asset = await importFile();
      final original = await File(asset.localPath!).readAsBytes();
      await expectLater(
        keys.unlockWithPassword(password: 'wrong', remoteWrappedKey: remote),
        throwsA(anything),
      );
      expect(keys.getMasterKey(), orderedEquals(localKey));
      expect(await storage.read(key: masterKeyName), base64Encode(localKey));
      expect(await storage.read(key: journalKey), isNull);
      expect(
        await File(asset.localPath!).readAsBytes(),
        orderedEquals(original),
      );
    },
  );

  test('journal persistence failure prevents any ciphertext changes', () async {
    final asset = await importFile();
    final original = await File(asset.localPath!).readAsBytes();
    storage.failWriteKey = journalKey;
    await expectLater(unlock(), throwsA(isA<LocalVaultMigrationException>()));
    expect(await File(asset.localPath!).readAsBytes(), orderedEquals(original));
    expect(await storage.read(key: masterKeyName), base64Encode(localKey));
    expect(await storage.read(key: journalKey), isNull);
  });

  test(
    'restarts safely after file migration but before secure key commit',
    () async {
      final asset = await importFile();
      storage.failWriteKey = masterKeyName;
      await expectLater(unlock(), throwsA(isA<LocalVaultMigrationException>()));
      expect(keys.isUnlocked, isFalse);
      expect(await storage.read(key: masterKeyName), base64Encode(localKey));
      expect(await storage.read(key: journalKey), isNotNull);

      storage.failWriteKey = null;
      final restarted = SecureKeyManager(
        secureStorage: storage,
        migrateLocalVault: migration.migrate,
      );
      await restarted.initialize();

      expect(restarted.getMasterKey(), orderedEquals(cloudKey));
      expect(await storage.read(key: journalKey), isNull);
      expect(
        (await AttachmentService(
          database: db,
          keyManager: restarted,
          storage: attachments,
        ).resolveAsset(asset.id)).data,
        orderedEquals(utf8.encode('local.txt')),
      );
    },
  );

  test(
    'interrupted file migration keeps both keys and resumes mixed ciphertext',
    () async {
      final first = await importFile('first.txt');
      final second = await importFile('second.txt');
      final originalSecond = await File(second.localPath!).readAsBytes();
      await File(second.localPath!).writeAsBytes([0, 1, 2]);
      await expectLater(unlock(), throwsA(isA<LocalVaultMigrationException>()));
      expect(keys.isUnlocked, isFalse);
      expect(await storage.read(key: journalKey), isNotNull);
      // The first file was atomically migrated; the DB transaction rolled back.
      expect(
        await AttachmentCrypto().decryptAttachment(
          encryptedEnvelopeBytes: await File(first.localPath!).readAsBytes(),
          masterKeyBytes: cloudKey,
          attachmentId: first.id,
        ),
        orderedEquals(utf8.encode('first.txt')),
      );
      await File(second.localPath!).writeAsBytes(originalSecond);

      // Explicit retry in the same app session must also resume the journal.
      await unlock();
      expect(keys.getMasterKey(), orderedEquals(cloudKey));
      expect(await storage.read(key: journalKey), isNull);
      expect(
        (await AttachmentService(
          database: db,
          keyManager: keys,
          storage: attachments,
        ).resolveAsset(second.id)).data,
        orderedEquals(utf8.encode('second.txt')),
      );
    },
  );

  test('recovery sign-in preserves encrypted files', () async {
    final asset = await importFile();
    await keys.unlockWithRecoveryKey(
      recoveryKey: 'cloud-recovery',
      remoteWrappedKey: remote,
    );
    expect(
      (await AttachmentService(
        database: db,
        keyManager: keys,
        storage: attachments,
      ).resolveAsset(asset.id)).data,
      orderedEquals(utf8.encode('local.txt')),
    );
    expect(keys.getMasterKey(), orderedEquals(cloudKey));
  });

  test('resumes a partially persisted active key record on restart', () async {
    final asset = await importFile();
    storage.failWriteKey = 'quietpaper_wrapped_master_key_v1';
    await expectLater(unlock(), throwsA(isA<LocalVaultMigrationException>()));
    expect(await storage.read(key: masterKeyName), base64Encode(cloudKey));
    expect(await storage.read(key: journalKey), isNotNull);
    storage.failWriteKey = null;
    final restarted = SecureKeyManager(
      secureStorage: storage,
      migrateLocalVault: migration.migrate,
    );
    await restarted.initialize();
    expect(restarted.getMasterKey(), orderedEquals(cloudKey));
    expect(
      (await restarted.getStoredWrappedKeyData())!.toJson(),
      remote.toJson(),
    );
    expect(
      (await AttachmentService(
        database: db,
        keyManager: restarted,
        storage: attachments,
      ).resolveAsset(asset.id)).data,
      orderedEquals(utf8.encode('local.txt')),
    );
    expect(await storage.read(key: journalKey), isNull);
  });

  for (final clear in [false, true]) {
    test(
      '${clear ? 'clear' : 'lock'} during migration cannot expose a late key',
      () async {
        await importFile();
        final started = Completer<void>();
        final release = Completer<void>();
        keys = SecureKeyManager(
          secureStorage: storage,
          migrateLocalVault: (oldKey, newKey) async {
            started.complete();
            await release.future;
            await migration.migrate(oldKey, newKey);
          },
        );
        await keys.initialize();
        final signingIn = unlock();
        final failed = expectLater(
          signingIn,
          throwsA(isA<LocalVaultMigrationException>()),
        );
        await started.future;
        expect(keys.isUnlocked, isFalse);
        expect(keys.getMasterKey, throwsStateError);
        final clearing = clear ? keys.clearLocalKeys() : null;
        if (!clear) keys.lock();
        release.complete();
        await failed;
        await clearing;
        expect(keys.isUnlocked, isFalse);
        if (clear) {
          expect(await storage.read(key: masterKeyName), isNull);
          expect(await storage.read(key: journalKey), isNull);
        } else {
          expect(await storage.read(key: journalKey), isNotNull);
          final restarted = SecureKeyManager(
            secureStorage: storage,
            migrateLocalVault: migration.migrate,
          );
          await restarted.initialize();
          expect(restarted.getMasterKey(), orderedEquals(cloudKey));
        }
      },
    );
  }
}
