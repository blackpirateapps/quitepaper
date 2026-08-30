import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'attachment_type_resolver.dart';

/// Manages ephemeral decrypted temporary files used strictly for external OS handoffs
/// (Open Externally, Share, Save As) with safe automatic lifecycle cleanup.
class AttachmentTempStorage {
  AttachmentTempStorage({this.customTempDirectoryProvider});

  final Future<Directory> Function()? customTempDirectoryProvider;
  static const _uuid = Uuid();

  /// Dedicated subdirectory inside cache for transient decrypted attachment files
  static const String tempFolderName = 'decrypted_attachments_temp';

  /// Resolves the root directory for temporary decrypted files.
  Future<Directory> getTempDecryptedDirectory() async {
    final rootDir = await (customTempDirectoryProvider?.call() ?? getTemporaryDirectory());
    final dir = Directory(p.join(rootDir.path, tempFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes decrypted plaintext bytes to an isolated ephemeral file for OS interaction.
  /// Returns the created temporary [File].
  Future<File> createTemporaryDecryptedFile({
    required String attachmentId,
    required String rawFileName,
    required Uint8List plaintextBytes,
  }) async {
    final sanitizedName = AttachmentTypeResolver.sanitizeFileName(
      rawFileName,
      fallback: 'attachment_$attachmentId',
    );

    final rootDir = await getTempDecryptedDirectory();
    // Use an isolated subfolder per operation to prevent filename collisions
    final operationDir = Directory(p.join(rootDir.path, '${attachmentId}_${_uuid.v4().substring(0, 8)}'));
    if (!await operationDir.exists()) {
      await operationDir.create(recursive: true);
    }

    final targetFile = File(p.join(operationDir.path, sanitizedName));
    await targetFile.writeAsBytes(plaintextBytes, flush: true);
    return targetFile;
  }

  /// Cleans up stale temporary decrypted files older than [maxAge] (default 1 hour).
  /// Safe to call on application launch or background transitions.
  Future<int> cleanStaleTempFiles({Duration maxAge = const Duration(hours: 1)}) async {
    try {
      final rootDir = await getTempDecryptedDirectory();
      if (!await rootDir.exists()) return 0;

      final now = DateTime.now();
      int deletedCount = 0;

      final entities = rootDir.listSync(recursive: false);
      for (final entity in entities) {
        try {
          var isStale = false;
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            isStale = true;
          } else if (entity is Directory) {
            final children = entity.listSync(recursive: true);
            if (children.isEmpty) {
              isStale = true;
            } else {
              for (final child in children) {
                final childStat = await child.stat();
                if (now.difference(childStat.modified) > maxAge) {
                  isStale = true;
                  break;
                }
              }
            }
          }

          if (isStale) {
            await entity.delete(recursive: true);
            deletedCount++;
          }
        } catch (e) {
          debugPrint('Error inspecting stale temp entity ${entity.path}: $e');
        }
      }

      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning stale attachment temp files: $e');
      return 0;
    }
  }

  /// Deletes a specific temporary file and its containing operation directory.
  Future<void> deleteTemporaryFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      final parent = file.parent;
      if (await parent.exists() && parent.path.contains(tempFolderName)) {
        final remaining = parent.listSync();
        if (remaining.isEmpty) {
          await parent.delete(recursive: true);
        }
      }
    } catch (_) {}
  }
}
