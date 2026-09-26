import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/attachments/attachment_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../domain/note_share.dart';
import 'share_service.dart';

/// Provides the [ShareService] wired with its dependencies.
final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService(
    apiClient: ref.watch(syncApiClientProvider),
    notesRepository: ref.watch(notesRepositoryProvider),
    attachmentService: ref.watch(attachmentServiceProvider),
    cloudinaryClient: ref.watch(cloudinaryClientProvider),
    database: ref.watch(databaseProvider),
  );
});

/// Loads the user's active shares for the management screen. Refreshable via
/// `ref.invalidate(sharesListProvider)` after create/update/delete.
final sharesListProvider = FutureProvider.autoDispose<List<NoteShare>>((ref) async {
  final service = ref.watch(shareServiceProvider);
  return service.listShares();
});
