import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/search/fuzzy_search_engine.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../notes/domain/note_metadata_extractor.dart';
import '../../domain/search_result.dart';

/// Compact, selectable row used only by the tablet/desktop search workspace.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.result,
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final SearchResultItem result;
  final String query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final note = result is NoteSearchMatch ? result as NoteSearchMatch : null;
    final document = result is DocumentSearchMatch
        ? result as DocumentSearchMatch
        : null;
    final metadata = note == null
        ? null
        : NoteMetadataExtractor.extract(note.note);
    final title = metadata?.displayTitle ?? document!.displayTitle;
    final locked = note?.note.isPasswordProtected ?? false;
    final snippet = locked
        ? 'Password protected'
        : note?.matchedSnippet ?? metadata?.previewSnippet ?? document!.snippet;
    final details = note != null
        ? [
            DateFormatter.formatNoteTileTime(note.note.updatedAt),
            ...note.note.tags.take(2).map((tag) => '#$tag'),
            if (metadata?.attachmentSummary != null)
              metadata!.attachmentSummary!,
          ].join(' · ')
        : [
            if (document!.matchedPageNumber > 0)
              'Page ${document.matchedPageNumber}',
            if (document.isOcrMatch) 'OCR',
            if (document.parentNoteTitle?.isNotEmpty ?? false)
              document.parentNoteTitle!,
          ].join(' · ');

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? colors.surfaceSubtle : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? colors.accent : Colors.transparent,
                  width: 3,
                ),
                bottom: BorderSide(
                  color: colors.divider.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : note != null
                      ? Icons.description_outlined
                      : document!.isAttachment
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: selected ? colors.accent : colors.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _highlighted(
                        context,
                        title,
                        AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        note?.titleHighlightSpans ??
                            document!.titleHighlightSpans,
                      ),
                      const SizedBox(height: 4),
                      _highlighted(
                        context,
                        snippet,
                        AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                        locked
                            ? const []
                            : note?.snippetHighlightSpans ??
                                  document!.snippetHighlightSpans,
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _highlighted(
    BuildContext context,
    String text,
    TextStyle style,
    List<TokenSpanDto> suppliedSpans,
  ) {
    final colors = context.appColors;
    final spans =
        (suppliedSpans.isEmpty
                ? FuzzySearchEngine.evaluate(
                    query: query,
                    text: text,
                  ).highlightSpans
                : suppliedSpans)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final children = <TextSpan>[];
    var cursor = 0;
    for (final span in spans) {
      if (span.start < cursor ||
          span.end > text.length ||
          span.end <= span.start) {
        continue;
      }
      children.add(TextSpan(text: text.substring(cursor, span.start)));
      children.add(
        TextSpan(
          text: text.substring(span.start, span.end),
          style: TextStyle(
            backgroundColor: colors.searchHighlight,
            color: colors.searchHighlightText,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = span.end;
    }
    children.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(
      TextSpan(style: style, children: children),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
