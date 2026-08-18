import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/markdown_import_item.dart';

final markdownImportServiceProvider = Provider<MarkdownImportService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return MarkdownImportService(repository);
});

class MarkdownImportService {
  MarkdownImportService(this._repository);

  final NotesRepository _repository;

  /// Imports all selected [items] into the local database repository.
  /// Returns the number of successfully imported notes.
  Future<int> importNotes(List<MarkdownImportItem> items) async {
    final selectedItems = items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      return 0;
    }

    var importedCount = 0;
    for (final item in selectedItems) {
      final note = Note(
        id: item.id,
        title: item.title,
        content: item.content,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        isPinned: false,
        isArchived: false,
        isTrashed: false,
        tags: item.tags,
      );

      await _repository.saveNote(note);
      importedCount++;
    }

    return importedCount;
  }
}
