import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/attachments/attachment_service.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/markdown_import_item.dart';

final markdownImportServiceProvider = Provider<MarkdownImportService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final attachmentService = ref.watch(attachmentServiceProvider);
  return MarkdownImportService(
    repository,
    attachmentService: attachmentService,
  );
});

class MarkdownImportService {
  MarkdownImportService(
    this._repository, {
    this.attachmentService,
  });

  final NotesRepository _repository;
  final AttachmentService? attachmentService;

  /// Imports all selected [items] into the local database repository,
  /// encrypting attached images and rewriting markdown image links to canonical `qp://asset/<UUID>` URIs.
  /// Returns the number of successfully imported notes.
  Future<int> importNotes(List<MarkdownImportItem> items) async {
    final selectedItems = items.where((i) => i.isSelected).toList();
    if (selectedItems.isEmpty) {
      return 0;
    }

    final service = attachmentService;
    // Map from file path to imported markdown snippet to avoid duplicate encryption
    final importedSnippetsByPath = <String, String>{};
    var importedCount = 0;

    for (final item in selectedItems) {
      var noteContent = item.content;

      if (service != null && item.imageReferences.isNotEmpty) {
        for (final ref in item.imageReferences) {
          if (!ref.isFound) continue;

          try {
            String? snippet;

            if (ref.resolvedFilePath != null && ref.resolvedFilePath!.isNotEmpty) {
              final path = ref.resolvedFilePath!;
              if (importedSnippetsByPath.containsKey(path)) {
                snippet = importedSnippetsByPath[path];
              } else {
                final file = File(path);
                if (await file.exists()) {
                  final result = await service.importImageFromFile(
                    file,
                    noteId: item.id,
                    preferredAltText: ref.altText,
                  );
                  snippet = result.markdownSnippet;
                  importedSnippetsByPath[path] = snippet;
                }
              }
            } else if (ref.pickedBytes != null && ref.pickedBytes!.isNotEmpty) {
              final mimeType = _inferMimeType(ref.displayName);
              final result = await service.importImageFromBytes(
                ref.pickedBytes!,
                mimeType: mimeType,
                noteId: item.id,
                preferredAltText: ref.altText,
              );
              snippet = result.markdownSnippet;
            }

            if (snippet != null && snippet.isNotEmpty) {
              noteContent = noteContent.replaceAll(ref.originalSyntax, snippet);
            }
          } catch (e) {
            debugPrint('Failed to import attachment ${ref.rawTarget} for note ${item.id}: $e');
            // Gracefully continue with original markdown link if encryption/import fails
          }
        }
      }

      final note = Note(
        id: item.id,
        title: item.title,
        content: noteContent,
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

  static String _inferMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    return 'image/png';
  }
}
