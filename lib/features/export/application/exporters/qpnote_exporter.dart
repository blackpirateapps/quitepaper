import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import '../../../../core/crypto/crypto_service.dart';
import '../../domain/export_models.dart';
import '../export_security_guard.dart';

/// Exporter for compiling notes into versioned full-fidelity Quiet Paper Note Packages (.qpnote).
class QpNotePackageExporter {
  QpNotePackageExporter({CryptoService? cryptoService})
      : _cryptoService = cryptoService ?? DefaultCryptoService();

  final CryptoService _cryptoService;

  static const String formatIdentifier = 'quietpaper:note:v1';
  static const String encryptedFormatIdentifier = 'quietpaper:encrypted-note-package:v1';
  static const int schemaVersion = 1;

  Future<ExportResult> exportQpNote({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final archive = Archive();

    // 1. note.md
    final markdownBytes = utf8.encode(snapshot.markdown);
    final markdownSha256 = _computeSha256(markdownBytes);
    archive.addFile(
      ArchiveFile(
        'note.md',
        markdownBytes.length,
        markdownBytes,
      ),
    );

    // 2. metadata.json
    final metadataMap = {
      'id': request.packageOptions.preserveIds ? snapshot.noteId : '',
      'title': snapshot.title,
      'createdAt': snapshot.createdAt.toUtc().toIso8601String(),
      'updatedAt': snapshot.updatedAt.toUtc().toIso8601String(),
      'isPinned': snapshot.isPinned,
      'isArchived': snapshot.isArchived,
      'isTrashed': request.packageOptions.preserveTrashState ? snapshot.isTrashed : false,
      'deletedAt': request.packageOptions.preserveTrashState
          ? snapshot.deletedAt?.toUtc().toIso8601String()
          : null,
      'tags': snapshot.tags,
      'isPasswordProtected': snapshot.isPasswordProtected,
      if (snapshot.passwordHint != null) 'passwordHint': snapshot.passwordHint,
    };
    final metadataJson = const JsonEncoder.withIndent('  ').convert(metadataMap);
    final metadataBytes = utf8.encode(metadataJson);
    final metadataSha256 = _computeSha256(metadataBytes);
    archive.addFile(
      ArchiveFile(
        'metadata.json',
        metadataBytes.length,
        metadataBytes,
      ),
    );

    // 3. Attachments
    final attachmentsManifest = <Map<String, dynamic>>[];
    if (request.includeAttachments && request.packageOptions.includeAttachments) {
      for (final att in snapshot.attachments) {
        if (att.hasBytes) {
          ExportSecurityGuard.validateRelativePathSafety(att.relativePath);
          archive.addFile(
            ArchiveFile(
              att.relativePath,
              att.bytes!.length,
              att.bytes!,
            ),
          );

          attachmentsManifest.add({
            'id': request.packageOptions.preserveIds ? att.id : '',
            'filename': att.originalFilename,
            'relativePath': att.relativePath,
            'mimeType': att.mimeType,
            'byteSize': att.byteSize,
            'sha256': att.sha256.isNotEmpty ? att.sha256 : _computeSha256(att.bytes!),
            if (att.width != null) 'width': att.width,
            if (att.height != null) 'height': att.height,
            'createdAt': att.createdAt.toUtc().toIso8601String(),
          });
        }
      }
    }

    // 4. Documents
    final documentsManifest = <Map<String, dynamic>>[];
    if (request.includeAttachments && request.packageOptions.includeAttachments) {
      for (final doc in snapshot.documents) {
        if (doc.hasBytes) {
          ExportSecurityGuard.validateRelativePathSafety(doc.relativePath);
          archive.addFile(
            ArchiveFile(
              doc.relativePath,
              doc.bytes!.length,
              doc.bytes!,
            ),
          );

          documentsManifest.add({
            'id': request.packageOptions.preserveIds ? doc.id : '',
            'title': doc.title,
            'relativePath': doc.relativePath,
            'mimeType': doc.mimeType,
            'byteSize': doc.byteSize,
            'pageCount': doc.pageCount,
            'sha256': doc.sha256.isNotEmpty ? doc.sha256 : _computeSha256(doc.bytes!),
            'source': doc.source,
            'createdAt': doc.createdAt.toUtc().toIso8601String(),
          });
        }
      }
    }

    // 5. OCR Datasets
    final ocrManifest = <Map<String, dynamic>>[];
    if (request.includeOcr && request.packageOptions.includeOcr) {
      for (final ocrItem in snapshot.ocrData) {
        final relFolder = ocrItem.relativePath.isNotEmpty
            ? ocrItem.relativePath
            : 'ocr/${ocrItem.resourceType}_${ocrItem.resourceId}';
        ExportSecurityGuard.validateRelativePathSafety(relFolder);

        final ocrFiles = <String>[];

        // Individual page transcripts
        for (final page in ocrItem.document.pages) {
          final pagePath = '$relFolder/page-${page.pageNumber.toString().padLeft(3, "0")}.txt';
          final pageBytes = utf8.encode(page.plainText);
          archive.addFile(
            ArchiveFile(
              pagePath,
              pageBytes.length,
              pageBytes,
            ),
          );
          ocrFiles.add(pagePath);
        }

        // OCR Structured Manifest
        final ocrDocJson = const JsonEncoder.withIndent('  ').convert(ocrItem.document.toJson());
        final ocrDocBytes = utf8.encode(ocrDocJson);
        final manifestPath = '$relFolder/manifest.json';
        archive.addFile(
          ArchiveFile(
            manifestPath,
            ocrDocBytes.length,
            ocrDocBytes,
          ),
        );

        ocrManifest.add({
          'resourceId': ocrItem.resourceId,
          'resourceType': ocrItem.resourceType,
          'relativePath': relFolder,
          'language': ocrItem.document.language.code,
          'pageCount': ocrItem.document.pages.length,
          'manifest': manifestPath,
          'files': ocrFiles,
        });
      }
    }

    // 6. manifest.json
    final manifestMap = {
      'format': formatIdentifier,
      'version': schemaVersion,
      'appVersion': '1.5.3',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'noteId': request.packageOptions.preserveIds ? snapshot.noteId : '',
      'title': snapshot.title,
      'isEncrypted': request.packageOptions.isEncrypted,
      'content': {
        'markdown': 'note.md',
        'sha256': markdownSha256,
      },
      'metadata': {
        'path': 'metadata.json',
        'sha256': metadataSha256,
      },
      'attachments': attachmentsManifest,
      'documents': documentsManifest,
      'ocr': ocrManifest,
    };

    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifestMap);
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestBytes.length,
        manifestBytes,
      ),
    );

    // 7. Compress into ZIP payload
    final zipEncoder = ZipEncoder();
    final rawZipBytes = zipEncoder.encode(archive);

    // 8. Handle optional package encryption
    Uint8List finalBytes;
    if (request.packageOptions.isEncrypted &&
        request.packageOptions.packagePassword != null &&
        request.packageOptions.packagePassword!.isNotEmpty) {
      final pass = request.packageOptions.packagePassword!;
      final saltBytes = _cryptoService.generateRandomBytes(16);
      final derivedKey = await _cryptoService.deriveKeyFromPassword(
        password: pass,
        salt: saltBytes,
        parameters: KdfParameters.standard,
      );

      final nonceBytes = _cryptoService.generateRandomBytes(24);
      final aad = utf8.encode(encryptedFormatIdentifier);

      final ciphertextBytes = await _cryptoService.encryptRawBytes(
        plaintextBytes: Uint8List.fromList(rawZipBytes),
        secretKey: derivedKey,
        nonce: nonceBytes,
        associatedData: aad,
      );

      final encryptedEnvelope = {
        'format': encryptedFormatIdentifier,
        'version': schemaVersion,
        'appVersion': '1.5.3',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'kdfSalt': base64Encode(saltBytes),
        'kdfParameters': KdfParameters.standard.toJson(),
        'nonce': base64Encode(nonceBytes),
        'ciphertext': base64Encode(ciphertextBytes),
        'manifestSummary': {
          'title': snapshot.title,
          'noteId': snapshot.noteId,
          'totalAttachments': snapshot.attachments.length,
          'totalDocuments': snapshot.documents.length,
          'totalTags': snapshot.tags.length,
        },
      };

      final envelopeJson = jsonEncode(encryptedEnvelope);
      finalBytes = Uint8List.fromList(utf8.encode(envelopeJson));
    } else {
      finalBytes = Uint8List.fromList(rawZipBytes);
    }

    await outputFile.writeAsBytes(finalBytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.qpnote,
      filename: filename,
      byteSize: finalBytes.length,
      mimeType: ExportFormat.qpnote.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static String _computeSha256(List<int> bytes) {
    return crypto.sha256.convert(bytes).toString();
  }
}
