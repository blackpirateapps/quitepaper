import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/notes_query_provider.dart';
import '../data/built_in_templates.dart';
import '../data/template_repository.dart';
import '../domain/note_template.dart';
import 'template_service.dart';

final templateRepositoryProvider = Provider(
  (ref) => TemplateRepository(ref.watch(databaseProvider)),
);
final templateServiceProvider = Provider(
  (ref) => TemplateService(
    repository: ref.watch(templateRepositoryProvider),
    notes: ref.watch(notesRepositoryProvider),
    onNoteCreated: () {
      ref.read(notesCollectionProvider.notifier).refresh();
      ref.read(syncEngineProvider).triggerSyncDebounced();
    },
  ),
);
final userTemplatesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(templateRepositoryProvider).watchUserTemplates(),
);
final templateFavoritesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(templateRepositoryProvider).watchFavoriteTemplateIds(),
);
final templateCatalogProvider =
    Provider.autoDispose<AsyncValue<List<NoteTemplate>>>((ref) {
      final users = ref.watch(userTemplatesProvider);
      final favorites = ref.watch(templateFavoritesProvider);
      if (users.hasError) return AsyncError(users.error!, users.stackTrace!);
      if (favorites.hasError) {
        return AsyncError(favorites.error!, favorites.stackTrace!);
      }
      if (!users.hasValue || !favorites.hasValue) return const AsyncLoading();
      return AsyncData([
        for (final template in [...builtInTemplates, ...users.requireValue])
          template.withFavorite(favorites.requireValue.contains(template.id)),
      ]);
    });
