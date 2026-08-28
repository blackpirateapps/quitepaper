import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import '../../../core/crypto/crypto_service.dart';
import 'export_security_guard.dart';

/// Structured validation result for `.qpnote` packages.
class QpNoteValidationResult {
  const QpNoteValidationResult({
    required this.isValid,
    required this.isEncrypted,
    this.formatVersion,
    this.manifest,
    this.noteTitle,
    this.noteId,
    this.totalAttachments = 0,
    this.totalDocuments = 0,
    this.totalOcrDatasets = 0,
    this.errors = const [],
    this.warnings = const [],
    this.unpackedArchive,
  });

  final bool isValid;
  final bool isEncrypted;
  final int? formatVersion;
  final Map<String, dynamic>? manifest;
  final String? noteTitle;
  final String? noteId;
  final int totalAttachments;
  final int totalDocuments;
  final int totalOcrDatasets;
  final List<String> errors;
  final List<String> warnings;
  final Archive? unpackedArchive;

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Package validation and security inspection service for `.qpnote` files.
class QpNoteValidator {
  QpNoteValidator({CryptoService? cryptoService})
      : _cryptoService = cryptoService ?? DefaultCryptoService();

  final CryptoService _cryptoService;

  static const String formatIdentifier = 'quietpaper:note:v1';
  static const String encryptedFormatIdentifier = 'quietpaper:encrypted-note-package:v1';
  static const int currentSupportedVersion = 1;

  /// Validates a `.qpnote` package file against security vulnerabilities, format schemas, and file integrity.
  Future<QpNoteValidationResult> validatePackageFile(
    File file, {
    String? packagePassword,
  }) async {
    if (!await file.exists()) {
      return const QpNoteValidationResult(
        isValid: false,
        isEncrypted: false,
        errors: ['Package file does not exist.'],
      );
    }

    try {
      final bytes = await file.readAsBytes();
      return validatePackageBytes(bytes, packagePassword: packagePassword);
    } catch (e) {
      return QpNoteValidationResult(
        isValid: false,
        isEncrypted: false,
        errors: ['Failed to read package file: $e'],
      );
    }
  }

  /// Validates raw `.qpnote` package bytes.
  Future<QpNoteValidationResult> validatePackageBytes(
    Uint8List rawBytes, {
    String? packagePassword,
  }) async {
    final errors = <String>[];
    final warnings = <String>[];

    if (rawBytes.isEmpty) {
      return const QpNoteValidationResult(
        isValid: false,
        isEncrypted: false,
        errors: ['Package payload is empty (0 bytes).'],
      );
    }

    Uint8List zipBytes = rawBytes;
    var isEncrypted = false;

    // 1. Check if package is an encrypted JSON envelope
    if (rawBytes.length >= 2 && rawBytes[0] == 0x7B) {
      // Starts with '{'
      try {
        final jsonStr = utf8.decode(rawBytes);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic> &&
            (decoded['format'] == encryptedFormatIdentifier || decoded.containsKey('ciphertext'))) {
          isEncrypted = true;

          if (packagePassword == null || packagePassword.isEmpty) {
            final summary = decoded['manifestSummary'] as Map<String, dynamic>?;
            return QpNoteValidationResult(
              isValid: true,
              isEncrypted: true,
              formatVersion: decoded['version'] as int? ?? 1,
              noteTitle: summary?['title'] as String?,
              noteId: summary?['noteId'] as String?,
              totalAttachments: summary?['totalAttachments'] as int? ?? 0,
              totalDocuments: summary?['totalDocuments'] as int? ?? 0,
              warnings: const ['Package is password-encrypted. Provide password to inspect contents.'],
            );
          }

          // Attempt decryption
          try {
            final salt = base64Decode(decoded['kdfSalt'] as String);
            final nonce = base64Decode(decoded['nonce'] as String);
            final ciphertext = base64Decode(decoded['ciphertext'] as String);
            final kdfParams = decoded['kdfParameters'] is Map<String, dynamic>
                ? KdfParameters.fromJson(decoded['kdfParameters'] as Map<String, dynamic>)
                : KdfParameters.standard;

            final key = await _cryptoService.deriveKeyFromPassword(
              password: packagePassword,
              salt: salt,
              parameters: kdfParams,
            );

            final aad = utf8.encode(encryptedFormatIdentifier);
            final decrypted = await _cryptoService.decryptRawBytes(
              combinedCiphertext: ciphertext,
              secretKey: key,
              nonce: nonce,
              associatedData: aad,
            );

            zipBytes = decrypted;
          } catch (decErr) {
            return const QpNoteValidationResult(
              isValid: false,
              isEncrypted: true,
              errors: ['Incorrect package password or corrupted encrypted archive.'],
            );
          }
        }
      } catch (_) {
        // Not a JSON envelope, proceed as raw ZIP
      }
    }

    // 2. Decode ZIP Container
    Archive archive;
    try {
      final zipDecoder = ZipDecoder();
      archive = zipDecoder.decodeBytes(zipBytes, verify: true);
    } catch (zipErr) {
      return QpNoteValidationResult(
        isValid: false,
        isEncrypted: isEncrypted,
        errors: ['Invalid ZIP container archive: $zipErr'],
      );
    }

    // 3. Path Traversal / Zip-Slip Security Inspection
    final archiveFilesByName = <String, ArchiveFile>{};
    for (final file in archive) {
      final path = file.name;
      try {
        ExportSecurityGuard.validateRelativePathSafety(path);
      } catch (pathErr) {
        errors.add('Security violation in package entry "$path": $pathErr');
      }
      archiveFilesByName[path] = file;
    }

    if (errors.isNotEmpty) {
      return QpNoteValidationResult(
        isValid: false,
        isEncrypted: isEncrypted,
        errors: errors,
      );
    }

    // 4. Inspect manifest.json
    final manifestFile = archiveFilesByName['manifest.json'];
    if (manifestFile == null) {
      return QpNoteValidationResult(
        isValid: false,
        isEncrypted: isEncrypted,
        errors: ['Missing required manifest.json in root of .qpnote package.'],
      );
    }

    Map<String, dynamic> manifest;
    try {
      final manifestJson = utf8.decode(manifestFile.content as List<int>);
      manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    } catch (e) {
      return QpNoteValidationResult(
        isValid: false,
        isEncrypted: isEncrypted,
        errors: ['Failed to parse manifest.json: $e'],
      );
    }

    // 5. Verify format identifier & version
    final format = manifest['format'] as String? ?? '';
    if (format != formatIdentifier) {
      errors.add('Unsupported package format identifier: "$format" (expected "$formatIdentifier")');
    }

    final version = manifest['version'] as int? ?? 0;
    if (version > currentSupportedVersion) {
      errors.add(
        'This Quiet Paper note package requires a newer version of Quiet Paper (package schema v$version, supported up to v$currentSupportedVersion).',
      );
    }

    // 6. Verify required content files
    final contentObj = manifest['content'] as Map<String, dynamic>?;
    final markdownRelPath = contentObj?['markdown'] as String? ?? 'note.md';
    final markdownFile = archiveFilesByName[markdownRelPath];
    if (markdownFile == null) {
      errors.add('Missing markdown document file referenced in manifest: "$markdownRelPath"');
    } else if (contentObj?['sha256'] != null && (contentObj!['sha256'] as String).isNotEmpty) {
      final actualSha = crypto.sha256.convert(markdownFile.content as List<int>).toString();
      final expectedSha = contentObj['sha256'] as String;
      if (actualSha != expectedSha) {
        errors.add('SHA-256 integrity verification failed for "$markdownRelPath"');
      }
    }

    final metadataObj = manifest['metadata'] is Map
        ? manifest['metadata'] as Map<String, dynamic>
        : {'path': manifest['metadata'] as String? ?? 'metadata.json'};
    final metadataRelPath = metadataObj['path'] as String? ?? 'metadata.json';
    final metadataFile = archiveFilesByName[metadataRelPath];
    if (metadataFile == null) {
      errors.add('Missing metadata file referenced in manifest: "$metadataRelPath"');
    }

    // 7. Verify attachments existence and SHA-256
    final rawAttachments = manifest['attachments'] as List? ?? [];
    for (final rawAtt in rawAttachments) {
      if (rawAtt is Map) {
        final relPath = rawAtt['relativePath'] as String? ?? '';
        final attFile = archiveFilesByName[relPath];
        if (attFile == null) {
          warnings.add('Attachment file referenced in manifest missing from archive: "$relPath"');
        } else if (rawAtt['sha256'] != null && (rawAtt['sha256'] as String).isNotEmpty) {
          final actualSha = crypto.sha256.convert(attFile.content as List<int>).toString();
          final expectedSha = rawAtt['sha256'] as String;
          if (actualSha != expectedSha) {
            warnings.add('Attachment SHA-256 mismatch for "$relPath"');
          }
        }
      }
    }

    // 8. Verify documents existence and SHA-256
    final rawDocuments = manifest['documents'] as List? ?? [];
    for (final rawDoc in rawDocuments) {
      if (rawDoc is Map) {
        final relPath = rawDoc['relativePath'] as String? ?? '';
        final docFile = archiveFilesByName[relPath];
        if (docFile == null) {
          warnings.add('Document file referenced in manifest missing from archive: "$relPath"');
        } else if (rawDoc['sha256'] != null && (rawDoc['sha256'] as String).isNotEmpty) {
          final actualSha = crypto.sha256.convert(docFile.content as List<int>).toString();
          final expectedSha = rawDoc['sha256'] as String;
          if (actualSha != expectedSha) {
            warnings.add('Document SHA-256 mismatch for "$relPath"');
          }
        }
      }
    }

    final rawOcr = manifest['ocr'] as List? ?? [];
    final title = manifest['title'] as String? ?? '';
    final noteId = manifest['noteId'] as String? ?? '';

    return QpNoteValidationResult(
      isValid: errors.isEmpty,
      isEncrypted: isEncrypted,
      formatVersion: version,
      manifest: manifest,
      noteTitle: title,
      noteId: noteId,
      totalAttachments: rawAttachments.length,
      totalDocuments: rawDocuments.length,
      totalOcrDatasets: rawOcr.length,
      errors: errors,
      warnings: warnings,
      unpackedArchive: errors.isEmpty ? archive : null,
    );
  }
}
