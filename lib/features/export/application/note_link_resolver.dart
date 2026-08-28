import '../../../core/database/app_database.dart';
import '../../../core/uri/quiet_paper_uri.dart';
import '../domain/export_models.dart';
import 'filename_generator.dart';

/// Coordinator for parsing, resolving, and formatting internal note links in exported documents.
class NoteLinkResolver {
  NoteLinkResolver({required this.database});

  final AppDatabase database;

  static final RegExp _noteLinkRegex = RegExp(
    r'(?<!!)\[([^\]]+)\]\((qp:\/\/note\/[a-zA-Z0-9\-]+(\?[^\)]*)?)\)',
  );
  static final RegExp _bareNoteUriRegex = RegExp(
    r'(?<!\()qp:\/\/note\/([a-zA-Z0-9\-]+)',
  );

  /// Rewrites internal note links in [markdown] based on [strategy].
  Future<String> transformNoteLinks(
    String markdown, {
    required NoteLinkStrategy strategy,
    ExportFormat targetFormat = ExportFormat.markdown,
  }) async {
    if (strategy == NoteLinkStrategy.preserveQuietPaperUri) {
      return markdown;
    }

    var result = markdown;

    // Cache looked-up note titles
    final noteTitles = <String, String>{};

    Future<String> getTitle(String noteId) async {
      if (noteTitles.containsKey(noteId)) {
        return noteTitles[noteId]!;
      }
      try {
        final noteWithTags = await database.getNoteWithTags(noteId);
        final title = noteWithTags?.note.title.trim().isNotEmpty == true
            ? noteWithTags!.note.title.trim()
            : 'Linked Note';
        noteTitles[noteId] = title;
        return title;
      } catch (_) {
        noteTitles[noteId] = 'Linked Note';
        return 'Linked Note';
      }
    }

    // 1. Process formatted markdown note links `[Text](qp://note/<UUID>)`
    final linkMatches = _noteLinkRegex.allMatches(markdown).toList();
    for (final match in linkMatches) {
      final fullMatch = match.group(0)!;
      final linkText = match.group(1)!;
      final uriStr = match.group(2)!;
      final qpUri = QuietPaperUri.tryParse(uriStr);

      if (qpUri != null && qpUri.isNote) {
        final noteId = qpUri.resourceId;
        final title = linkText.isNotEmpty ? linkText : await getTitle(noteId);

        switch (strategy) {
          case NoteLinkStrategy.preserveQuietPaperUri:
            break;
          case NoteLinkStrategy.preserveAsLinks:
            result = result.replaceAll(fullMatch, '[$title]($uriStr)');
            break;
          case NoteLinkStrategy.plainTextRepresentation:
            result = result.replaceAll(fullMatch, title);
            break;
          case NoteLinkStrategy.rewriteToRelativeFiles:
            final sanitizedName = FilenameGenerator.generateFilename(
              title: title,
              format: targetFormat,
            );
            result = result.replaceAll(fullMatch, '[$title]($sanitizedName)');
            break;
        }
      }
    }

    // 2. Process bare note URIs
    final bareMatches = _bareNoteUriRegex.allMatches(markdown).toList();
    for (final match in bareMatches) {
      final fullMatch = match.group(0)!;
      final noteId = match.group(1)!;
      final title = await getTitle(noteId);

      switch (strategy) {
        case NoteLinkStrategy.preserveQuietPaperUri:
          break;
        case NoteLinkStrategy.preserveAsLinks:
          result = result.replaceAll(fullMatch, '[$title](qp://note/$noteId)');
          break;
        case NoteLinkStrategy.plainTextRepresentation:
          result = result.replaceAll(fullMatch, title);
          break;
        case NoteLinkStrategy.rewriteToRelativeFiles:
          final sanitizedName = FilenameGenerator.generateFilename(
            title: title,
            format: targetFormat,
          );
          result = result.replaceAll(fullMatch, '[$title]($sanitizedName)');
          break;
      }
    }

    return result;
  }
}
