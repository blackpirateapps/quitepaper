import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Handles local disk persistence of encrypted document payloads (.qpd)
/// and ephemeral in-memory decrypted byte caching.
class DocumentLocalStorage {
  DocumentLocalStorage({
    this.customDocumentsDirectory,
    this.customTempDirectory,
  });

  final Directory? customDocumentsDirectory;
  final Directory? customTempDirectory;

  /// In-memory ephemeral cache of decrypted PDF bytes: documentId -> Uint8List
  final Map<String, Uint8List> _decryptedMemoryCache = {};

  Future<Directory> get _documentsDir async {
    if (customDocumentsDirectory != null) {
      if (!await customDocumentsDirectory!.exists()) {
        await customDocumentsDirectory!.create(recursive: true);
      }
      return customDocumentsDirectory!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final docDir = Directory(p.join(appDir.path, 'documents'));
    if (!await docDir.exists()) {
      await docDir.create(recursive: true);
    }
    return docDir;
  }

  Future<Directory> get _tempDir async {
    if (customTempDirectory != null) {
      if (!await customTempDirectory!.exists()) {
        await customTempDirectory!.create(recursive: true);
      }
      return customTempDirectory!;
    }
    final systemTemp = await getTemporaryDirectory();
    final scanTemp = Directory(p.join(systemTemp.path, 'scan_temp'));
    if (!await scanTemp.exists()) {
      await scanTemp.create(recursive: true);
    }
    return scanTemp;
  }

  /// Builds local file path for an encrypted document.
  Future<String> getEncryptedFilePath(String documentId) async {
    final dir = await _documentsDir;
    return p.join(dir.path, '$documentId.qpd');
  }

  /// Saves encrypted document ciphertext bytes to app-private storage.
  Future<String> saveEncryptedBytes({
    required String documentId,
    required Uint8List encryptedBytes,
  }) async {
    final filePath = await getEncryptedFilePath(documentId);
    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes, flush: true);
    return filePath;
  }

  /// Reads encrypted document ciphertext bytes from local disk.
  Future<Uint8List?> readEncryptedBytes({
    required String documentId,
    String? localPath,
  }) async {
    try {
      final targetPath = localPath ?? await getEncryptedFilePath(documentId);
      final file = File(targetPath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      // Fallback: check canonical directory if localPath was non-standard
      if (localPath != null) {
        final canonicalPath = await getEncryptedFilePath(documentId);
        final canonicalFile = File(canonicalPath);
        if (await canonicalFile.exists()) {
          return await canonicalFile.readAsBytes();
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error reading encrypted document file: $e');
      return null;
    }
  }

  /// Deletes encrypted document file from disk.
  Future<void> deleteEncryptedFile({required String documentId}) async {
    try {
      final filePath = await getEncryptedFilePath(documentId);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting encrypted document file: $e');
    }
  }

  /// Checks whether an encrypted document file exists locally.
  Future<bool> hasEncryptedFile({required String documentId}) async {
    try {
      final filePath = await getEncryptedFilePath(documentId);
      final file = File(filePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // IN-MEMORY DECRYPTED BYTE CACHE
  // ==========================================

  void putDecryptedCache(String documentId, Uint8List plaintextBytes) {
    _decryptedMemoryCache[documentId] = plaintextBytes;
  }

  Uint8List? getDecryptedCache(String documentId) {
    return _decryptedMemoryCache[documentId];
  }

  void invalidateDecryptedCache(String documentId) {
    _decryptedMemoryCache.remove(documentId);
  }

  void clearDecryptedCache() {
    _decryptedMemoryCache.clear();
  }

  // ==========================================
  // TEMPORARY SCAN SESSION CLEANUP
  // ==========================================

  Future<void> cleanTempScanFiles({String? sessionId}) async {
    try {
      final baseTemp = await _tempDir;
      if (sessionId != null) {
        final sessionDir = Directory(p.join(baseTemp.path, sessionId));
        if (await sessionDir.exists()) {
          await sessionDir.delete(recursive: true);
        }
      } else {
        if (await baseTemp.exists()) {
          final entities = await baseTemp.list().toList();
          for (final entity in entities) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning temp scan files: $e');
    }
  }
}
