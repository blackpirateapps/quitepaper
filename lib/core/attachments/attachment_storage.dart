import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages local storage of encrypted attachment payloads in app-private directories
/// and provides an ephemeral, in-memory plaintext cache for UI rendering.
class AttachmentLocalStorage {
  AttachmentLocalStorage({
    this.customBaseDirectory,
  });

  final Directory? customBaseDirectory;
  Directory? _cachedAttachmentsDir;

  /// Ephemeral in-memory plaintext cache: key -> Uint8List.
  /// Strictly in RAM; purged on logout or clear keys.
  static final _MemoryCache _memoryCache = _MemoryCache(maxEntries: 40);

  /// Resolves the app-private directory where encrypted attachment blobs reside.
  Future<Directory> getAttachmentsDirectory() async {
    if (customBaseDirectory != null) {
      if (!await customBaseDirectory!.exists()) {
        await customBaseDirectory!.create(recursive: true);
      }
      return customBaseDirectory!;
    }

    if (_cachedAttachmentsDir != null && await _cachedAttachmentsDir!.exists()) {
      return _cachedAttachmentsDir!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedAttachmentsDir = dir;
    return dir;
  }

  String _getFileName(String attachmentId, String variant) {
    if (variant == 'original') {
      return '$attachmentId.enc';
    }
    return '${attachmentId}_$variant.enc';
  }

  /// Saves encrypted bytes to local app-private storage.
  Future<String> saveEncryptedBytes({
    required String attachmentId,
    required Uint8List encryptedBytes,
    String variant = 'original',
  }) async {
    final dir = await getAttachmentsDirectory();
    final fileName = _getFileName(attachmentId, variant);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(encryptedBytes, flush: true);
    return file.path;
  }

  /// Reads encrypted bytes from local storage if present.
  Future<Uint8List?> readEncryptedBytes({
    required String attachmentId,
    String variant = 'original',
    String? localPath,
  }) async {
    if (localPath != null && localPath.isNotEmpty) {
      final customFile = File(localPath);
      if (await customFile.exists()) {
        return customFile.readAsBytes();
      }
    }

    final dir = await getAttachmentsDirectory();
    final fileName = _getFileName(attachmentId, variant);
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      return file.readAsBytes();
    }
    return null;
  }

  /// Checks if the encrypted file exists locally.
  Future<bool> hasEncryptedFile({
    required String attachmentId,
    String variant = 'original',
    String? localPath,
  }) async {
    if (localPath != null && localPath.isNotEmpty) {
      final customFile = File(localPath);
      if (await customFile.exists()) return true;
    }

    final dir = await getAttachmentsDirectory();
    final fileName = _getFileName(attachmentId, variant);
    final file = File('${dir.path}/$fileName');
    return file.exists();
  }

  /// Deletes local encrypted file for an attachment.
  Future<void> deleteEncryptedFile({
    required String attachmentId,
    String variant = 'original',
    String? localPath,
  }) async {
    invalidateDecryptedCache(attachmentId, variant: variant);

    if (localPath != null && localPath.isNotEmpty) {
      final customFile = File(localPath);
      if (await customFile.exists()) {
        try {
          await customFile.delete();
        } catch (_) {}
      }
    }

    final dir = await getAttachmentsDirectory();
    final fileName = _getFileName(attachmentId, variant);
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // ==========================================
  // IN-MEMORY TEMPORARY PLAINTEXT CACHE
  // ==========================================

  /// Retrieves temporary decrypted plaintext bytes from RAM cache.
  Uint8List? getDecryptedCache(String attachmentId, {String variant = 'original'}) {
    return _memoryCache.get('$attachmentId:$variant');
  }

  /// Stores temporary decrypted plaintext bytes in RAM cache for fast rendering.
  void putDecryptedCache(
    String attachmentId,
    Uint8List plaintextBytes, {
    String variant = 'original',
  }) {
    _memoryCache.put('$attachmentId:$variant', plaintextBytes);
  }

  /// Invalidates RAM cache for a specific attachment.
  void invalidateDecryptedCache(String attachmentId, {String variant = 'original'}) {
    _memoryCache.remove('$attachmentId:$variant');
  }

  /// Purges all in-memory plaintext caches (invoked on user logout / key lock).
  static void purgeAllMemoryCache() {
    _memoryCache.clear();
  }
}

/// Simple LRU memory cache for in-memory temporary image buffers.
class _MemoryCache {
  _MemoryCache({this.maxEntries = 40});

  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  Uint8List? get(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  void put(String key, Uint8List value) {
    _cache.remove(key);
    _cache[key] = value;
    if (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}
