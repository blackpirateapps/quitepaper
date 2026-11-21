import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/documents/document_provider.dart';
import '../../../core/storage/app_storage_path_resolver.dart';
import '../../../core/sync/sync_provider.dart';
import '../../email_import/application/email_import_gateway.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/notes_query_provider.dart';
import '../data/watched_import_repository.dart';
import 'canonical_import_adapter.dart';
import 'native_watched_engine.dart';
import 'android_watched_engine.dart';
import 'watched_import_controller.dart';

bool get supportsWatchedImport =>
    !kIsWeb &&
    const {
      TargetPlatform.linux,
      TargetPlatform.android,
    }.contains(defaultTargetPlatform);

final watchedImportControllerProvider =
    ChangeNotifierProvider<WatchedImportController>((ref) {
      final store = WatchedImportRepositoryAdapter(ref.watch(databaseProvider));
      final keys = ref.watch(keyManagerProvider);
      final controller = WatchedImportController(
        store: store,
        engine: defaultTargetPlatform == TargetPlatform.android
            ? AndroidWatchedEngine()
            : NativeWatchedEngine(),
        prepareVault: () => ref.read(emailImportGatewayProvider).initialize(),
        importer: CanonicalImportAdapter(
          store: store,
          email: ref.watch(emailImportServiceProvider),
          notes: ref.watch(notesRepositoryProvider),
          attachments: ref.watch(attachmentServiceProvider),
          documents: ref.watch(documentServiceProvider),
        ),
        scope: () async {
          final user = ref.read(authServiceProvider).currentUser;
          return user == null ? store.deviceScope() : 'account:${user.id}';
        },
        isUnlocked: () => keys.isUnlocked,
        isScopeCurrent: (scope) {
          final user = ref.read(authServiceProvider).currentUser;
          return user == null
              ? scope.startsWith('device:')
              : scope == 'account:${user.id}';
        },
        forbiddenPaths: () async => [
          (await AppStoragePathResolver.getDataDirectory()).path,
          (await AppStoragePathResolver.getCacheDirectory()).path,
          Directory.systemTemp.path,
        ],
        onImported: () async {
          await ref.read(notesCollectionProvider.notifier).refresh();
          ref.read(syncEngineProvider).triggerSyncDebounced();
        },
      );
      // Account checks also run before each native delivery and canonical commit.
      ref.listen(currentUserProvider, (_, next) {
        controller.accountChanged();
      });
      return controller;
    });
