import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../attachments/attachment_crypto.dart';
import '../attachments/attachment_storage.dart';
import '../database/app_database.dart';
import '../documents/annotations/annotation_crypto.dart';
import '../documents/document_crypto.dart';
import '../documents/document_storage.dart';
import '../ocr/ocr_crypto.dart';
import 'crypto_service.dart';

/// Moves device-only ciphertext onto an existing account's master key.
/// The key manager journals both keys before invoking this operation. Files are
/// replaced atomically, DB changes are transactional, and retries accept files
/// already encrypted with the destination key after an interrupted attempt.
class LocalVaultKeyMigration {
  LocalVaultKeyMigration({
    required this.database,
    required this.attachments,
    required this.documents,
    required this.crypto,
  });

  final AppDatabase database;
  final AttachmentLocalStorage attachments;
  final DocumentLocalStorage documents;
  final CryptoService crypto;

  Future<void> migrate(Uint8List oldKey, Uint8List newKey) async {
    final commitment =
        '${crypto.computeKeyAuthCommitment(oldKey)}:'
        '${crypto.computeKeyAuthCommitment(newKey)}';
    await database.transaction(() async {
      if (await database.getSyncMetadata('local_vault_key_migration') ==
          commitment) {
        return;
      }
      final assets = await database.select(database.attachmentsTable).get();
      for (final asset in assets) {
        final directory = await attachments.getAttachmentsDirectory();
        await _file(
          asset.localPath,
          '${directory.path}/${asset.id}.enc',
          AttachmentCrypto.magicBytes,
          AttachmentCrypto.buildAad(asset.id),
          oldKey,
          newKey,
          required: !asset.isDeleted,
        );
      }
      final variants = await database
          .select(database.attachmentVariantsTable)
          .get();
      for (final variant in variants) {
        final directory = await attachments.getAttachmentsDirectory();
        final suffix = variant.variantType == 'original'
            ? ''
            : '_${variant.variantType}';
        await _file(
          variant.localPath,
          '${directory.path}/${variant.attachmentId}$suffix.enc',
          AttachmentCrypto.magicBytes,
          AttachmentCrypto.buildAad(
            variant.attachmentId,
            variant: variant.variantType,
          ),
          oldKey,
          newKey,
        );
        await (database.update(
          database.attachmentVariantsTable,
        )..where((t) => t.id.equals(variant.id))).write(
          const AttachmentVariantsTableCompanion(
            cloudUrl: Value(null),
            cloudPublicId: Value(null),
          ),
        );
      }
      final docs = await database.select(database.documentsTable).get();
      for (final document in docs) {
        await _file(
          document.localPath,
          await documents.getEncryptedFilePath(document.id),
          DocumentCrypto.magicBytes,
          DocumentCrypto.buildAad(document.id),
          oldKey,
          newKey,
          required: !document.isDeleted,
        );
        await _file(
          null,
          await documents.getEncryptedAnnotatedFilePath(document.id),
          DocumentCrypto.magicBytes,
          DocumentCrypto.buildAad(document.id),
          oldKey,
          newKey,
        );
        // Thumbnails are disposable caches; PDFs and annotations remain intact.
        await (database.update(database.documentsTable)
              ..where((t) => t.id.equals(document.id)))
            .write(const DocumentsTableCompanion(thumbnailPath: Value(null)));
      }

      final attachmentOcr = await database
          .select(database.attachmentOcrPagesTable)
          .get();
      for (final page in attachmentOcr) {
        if (page.encryptedPayload.isEmpty && page.isDeleted) continue;
        final payload = await _envelope(
          base64Decode(page.encryptedPayload),
          OcrCrypto.magicBytes,
          OcrCrypto.buildAad(page.attachmentId),
          oldKey,
          newKey,
        );
        await (database.update(database.attachmentOcrPagesTable)..where(
              (t) =>
                  t.attachmentId.equals(page.attachmentId) &
                  t.pageNumber.equals(page.pageNumber),
            ))
            .write(
              AttachmentOcrPagesTableCompanion(
                encryptedPayload: Value(base64Encode(payload)),
                isDirty: const Value(true),
              ),
            );
      }
      final documentOcr = await database
          .select(database.documentOcrPagesTable)
          .get();
      for (final page in documentOcr) {
        if (page.encryptedPayload.isEmpty && page.isDeleted) continue;
        final payload = await _envelope(
          base64Decode(page.encryptedPayload),
          OcrCrypto.magicBytes,
          OcrCrypto.buildAad(page.documentId),
          oldKey,
          newKey,
        );
        await (database.update(database.documentOcrPagesTable)..where(
              (t) =>
                  t.documentId.equals(page.documentId) &
                  t.pageNumber.equals(page.pageNumber),
            ))
            .write(
              DocumentOcrPagesTableCompanion(
                encryptedPayload: Value(base64Encode(payload)),
                isDirty: const Value(true),
              ),
            );
      }
      final annotations = await database
          .select(database.documentAnnotationsTable)
          .get();
      for (final page in annotations) {
        final payload = await _envelope(
          base64Decode(page.encryptedPayload),
          AnnotationCrypto.magicBytes,
          AnnotationCrypto.buildAad(page.documentId, page.pageNumber - 1),
          oldKey,
          newKey,
        );
        await (database.update(database.documentAnnotationsTable)..where(
              (t) =>
                  t.documentId.equals(page.documentId) &
                  t.pageNumber.equals(page.pageNumber),
            ))
            .write(
              DocumentAnnotationsTableCompanion(
                encryptedPayload: Value(base64Encode(payload)),
                isDirty: const Value(true),
              ),
            );
      }

      final aliases = await database.select(database.placeAliasesTable).get();
      for (final alias in aliases) {
        if (alias.contentCiphertext.isEmpty && alias.isDeleted) continue;
        final envelope = EncryptedEnvelope(
          algorithm: 'xchacha20-poly1305',
          nonce: alias.contentNonce,
          ciphertext: alias.contentCiphertext,
          version: alias.contentVersion,
          keyVersion: alias.encryptionKeyVersion,
        );
        // Alias rows change atomically with the DB transaction, unlike files.
        final plaintext = await crypto.decryptPlaceAliasPayload(
          envelope: envelope,
          masterKeyBytes: oldKey,
          placeAliasId: alias.id,
        );
        final id = crypto.computePlaceAliasId(
          matchKey: plaintext.matchKey,
          masterKeyBytes: newKey,
        );
        final migrated = await crypto.encryptPlaceAliasPayload(
          plaintext: plaintext,
          masterKeyBytes: newKey,
          placeAliasId: id,
        );
        await (database.delete(
          database.placeAliasesTable,
        )..where((t) => t.id.equals(alias.id))).go();
        await database
            .into(database.placeAliasesTable)
            .insert(
              alias.copyWith(
                id: id,
                contentCiphertext: migrated.ciphertext,
                contentNonce: migrated.nonce,
                encryptionKeyVersion: migrated.keyVersion,
                isDirty: true,
              ),
            );
      }
      await database
          .update(database.attachmentsTable)
          .write(
            const AttachmentsTableCompanion(
              isDirty: Value(true),
              uploadState: Value('upload_pending'),
              encryptionKeyVersion: Value(1),
              cloudUrl: Value(null),
              cloudPublicId: Value(null),
            ),
          );
      await database
          .update(database.documentsTable)
          .write(
            const DocumentsTableCompanion(
              isDirty: Value(true),
              uploadState: Value('upload_pending'),
              encryptionKeyVersion: Value(1),
              cloudUrl: Value(null),
              cloudPublicId: Value(null),
            ),
          );
      // Allows a retry after DB commit but before secure key persistence.
      await database.setSyncMetadata('local_vault_key_migration', commitment);
    });
    AttachmentLocalStorage.purgeAllMemoryCache();
    documents.clearDecryptedCache();
  }

  Future<void> _file(
    String? localPath,
    String canonicalPath,
    List<int> magic,
    String aad,
    Uint8List oldKey,
    Uint8List newKey, {
    bool required = false,
  }) async {
    final candidates = {
      if (localPath != null && localPath.isNotEmpty) localPath,
      canonicalPath,
    };
    var found = false;
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      found = true;
      final original = await file.readAsBytes();
      final migrated = await _envelope(original, magic, aad, oldKey, newKey);
      if (identical(original, migrated)) continue;
      final temporary = File('$path.rekey');
      await temporary.writeAsBytes(migrated, flush: true);
      await temporary.rename(path);
    }
    if (required && !found) {
      throw StateError(
        'A local encrypted file is missing. Restore it before signing in.',
      );
    }
  }

  Future<Uint8List> _envelope(
    Uint8List bytes,
    List<int> magic,
    String aad,
    Uint8List oldKey,
    Uint8List newKey,
  ) async {
    if (bytes.length < 48 ||
        !List.generate(4, (i) => bytes[i] == magic[i]).every((same) => same) ||
        ByteData.sublistView(bytes, 4, 8).getUint16(0, Endian.big) != 1) {
      throw StateError('A local encrypted file is damaged or unsupported.');
    }
    final associatedData = utf8.encode(aad);
    Future<Uint8List> decrypt(Uint8List key) => crypto.decryptRawBytes(
      combinedCiphertext: bytes.sublist(32),
      secretKey: SecretKey(key),
      nonce: bytes.sublist(8, 32),
      associatedData: associatedData,
    );
    try {
      final alreadyMigrated = await decrypt(newKey);
      alreadyMigrated.fillRange(0, alreadyMigrated.length, 0);
      return bytes;
    } catch (_) {
      // A previous interrupted attempt may have migrated only some files.
    }
    final plaintext = await decrypt(oldKey);
    try {
      final nonce = crypto.generateRandomBytes(24);
      final ciphertext = await crypto.encryptRawBytes(
        plaintextBytes: plaintext,
        secretKey: SecretKey(newKey),
        nonce: nonce,
        associatedData: associatedData,
      );
      final header = Uint8List.fromList(bytes.sublist(0, 8));
      ByteData.sublistView(header).setUint16(6, 1, Endian.big);
      return (BytesBuilder(copy: false)
            ..add(header)
            ..add(nonce)
            ..add(ciphertext))
          .takeBytes();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}
