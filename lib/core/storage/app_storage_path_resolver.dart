import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized resolver for application storage paths conforming strictly to
/// platform conventions (XDG Base Directory specification on Linux,
/// application sandbox on mobile).
class AppStoragePathResolver {
  const AppStoragePathResolver._();

  @visibleForTesting
  static Directory? customDataDirectory;

  static bool _migrationChecked = false;

  /// Returns the root data directory for application-private data
  /// (SQLite database, attachments, documents, voice notes, downloaded fonts).
  ///
  /// On Linux: Resolves to `~/.local/share/quitepaper` ($XDG_DATA_HOME).
  /// On Android / iOS / others: Resolves to standard application documents directory.
  static Future<Directory> getDataDirectory() async {
    if (customDataDirectory != null) {
      if (!await customDataDirectory!.exists()) {
        await customDataDirectory!.create(recursive: true);
      }
      return customDataDirectory!;
    }

    if (!kIsWeb && Platform.isLinux) {
      final supportDir = await getApplicationSupportDirectory();
      if (!_migrationChecked && !Platform.environment.containsKey('FLUTTER_TEST')) {
        _migrationChecked = true;
        await _migrateLegacyLinuxDataIfNeeded(supportDir);
      }
      if (!await supportDir.exists()) {
        await supportDir.create(recursive: true);
      }
      return supportDir;
    }

    return getApplicationDocumentsDirectory();
  }

  /// Returns the cache/temporary directory for ephemeral files (decrypted previews, scan temp).
  static Future<Directory> getCacheDirectory() async {
    return getTemporaryDirectory();
  }

  /// Automatically migrates legacy data from `~/Documents` to `~/.local/share/quitepaper`
  /// on Linux if existing database files are detected, ensuring zero data loss.
  static Future<void> _migrateLegacyLinuxDataIfNeeded(Directory targetDir) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      await migrateDirectories(sourceDir: docDir, targetDir: targetDir);
    } catch (e) {
      debugPrint('[AppStoragePathResolver] Migration warning (ignored): $e');
    }
  }

  @visibleForTesting
  static Future<void> migrateDirectories({
    required Directory sourceDir,
    required Directory targetDir,
  }) async {
    final legacyDb = File(p.join(sourceDir.path, 'quiet_paper.sqlite'));
    final targetDb = File(p.join(targetDir.path, 'quiet_paper.sqlite'));

    if (await legacyDb.exists() && !await targetDb.exists()) {
      debugPrint('[AppStoragePathResolver] Migrating legacy Linux data from ${sourceDir.path} to ${targetDir.path}...');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Migrate SQLite database and WAL files
      for (final ext in ['', '-wal', '-shm']) {
        final srcFile = File('${legacyDb.path}$ext');
        final dstFile = File('${targetDb.path}$ext');
        if (await srcFile.exists() && !await dstFile.exists()) {
          try {
            await srcFile.rename(dstFile.path);
          } catch (e) {
            await srcFile.copy(dstFile.path);
            await srcFile.delete();
          }
        }
      }

      // Migrate subdirectories: attachments, documents, voice_notes, fonts
      const subDirs = ['attachments', 'documents', 'voice_notes', 'fonts'];
      for (final dirName in subDirs) {
        final srcDir = Directory(p.join(sourceDir.path, dirName));
        final dstDir = Directory(p.join(targetDir.path, dirName));
        if (await srcDir.exists() && !await dstDir.exists()) {
          try {
            await srcDir.rename(dstDir.path);
          } catch (e) {
            await _copyDirectory(srcDir, dstDir);
            await srcDir.delete(recursive: true);
          }
        }
      }
      debugPrint('[AppStoragePathResolver] Legacy Linux data migration complete.');
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  @visibleForTesting
  static void resetMigrationState() {
    _migrationChecked = false;
    customDataDirectory = null;
  }
}
