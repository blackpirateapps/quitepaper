import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../storage/app_storage_path_resolver.dart';
import '../../features/notes/application/notes_provider.dart';
import '../attachments/attachment_storage.dart';
import '../sync/sync_provider.dart';

final vaultEraseServiceProvider = Provider<VaultEraseService>((ref) {
  return VaultEraseService(ref: ref);
});

/// Dedicated authoritative service for explicit and irreversible local vault erasure.
///
/// Disconnects account session, clears all SQLite tables (notes, tags, attachments,
/// documents, versions, OCR, sync queues, metadata), deletes on-disk encrypted
/// attachment & document binaries, purges decrypted in-memory caches, and
/// destroys persisted master encryption key material.
///
/// Unrelated application preferences (theme, typography, update snooze) are preserved.
class VaultEraseService {
  VaultEraseService({required this.ref});

  final Ref ref;

  Future<void> eraseLocalVault() async {
    debugPrint('[VaultEraseService] Beginning explicit local vault erasure...');

    // 1. Disconnect and clear Firebase auth session credentials
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signOut();
    } catch (e) {
      debugPrint('[VaultEraseService] Error signing out auth: $e');
    }

    // 2. Reset sync engine state & cursor
    try {
      final engine = ref.read(syncEngineProvider);
      await engine.resetSyncCursor();
    } catch (e) {
      debugPrint('[VaultEraseService] Error resetting sync engine: $e');
    }

    // 3. Clear all SQLite database tables & FTS virtual tables
    try {
      final db = ref.read(databaseProvider);
      await db.eraseAllLocalVaultData();
    } catch (e) {
      debugPrint('[VaultEraseService] Error clearing SQLite tables: $e');
    }

    // 4. Delete local encrypted attachment and document files on disk
    try {
      final appDocDir = await AppStoragePathResolver.getDataDirectory();

      final attachmentsDir = Directory(p.join(appDocDir.path, 'attachments'));
      if (await attachmentsDir.exists()) {
        await attachmentsDir.delete(recursive: true);
      }

      final docsDir = Directory(p.join(appDocDir.path, 'documents'));
      if (await docsDir.exists()) {
        await docsDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[VaultEraseService] Error removing disk files: $e');
    }

    // 5. Clear ephemeral in-memory decrypted image & document caches
    AttachmentLocalStorage.purgeAllMemoryCache();

    // 6. Erase hardware-backed persisted master key and wrapped key in SecureStorage
    try {
      final keyManager = ref.read(keyManagerProvider);
      await keyManager.clearLocalKeys();
    } catch (e) {
      debugPrint('[VaultEraseService] Error clearing local keys: $e');
    }

    debugPrint('[VaultEraseService] Explicit local vault erasure complete.');
  }
}
