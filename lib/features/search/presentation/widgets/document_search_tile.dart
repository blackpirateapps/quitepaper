import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/search/fuzzy_search_engine.dart';
import '../../domain/search_result.dart';

/// Interactive search result tile for scanned documents and OCR text matches
class DocumentSearchTile extends StatelessWidget {
  const DocumentSearchTile({
    super.key,
    required this.match,
    required this.searchQuery,
    required this.onTap,
  });

  final DocumentSearchMatch match;
  final String searchQuery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final doc = match.document;
    final isOcr = match.isOcrMatch;
    final isFuzzy = match.isFuzzy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 13.0,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.divider.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document leading icon badge
              Container(
                width: 42,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.3),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: colors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Match details & snippet column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Page Badge Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildFuzzyHighlightedText(
                            text: doc.title,
                            query: searchQuery,
                            baseStyle: AppTypography.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.0,
                            ),
                            highlightColor: colors.accent,
                            textColor: colors.textPrimary,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: colors.divider.withValues(alpha: 0.8),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Page ${match.matchedPageNumber}',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3.0),

                    // Parent Note Link and Match Category Badge
                    Row(
                      children: [
                        Icon(
                          match.parentNoteTitle != null
                              ? Icons.description_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 13,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            match.parentNoteTitle != null
                                ? 'In: ${match.parentNoteTitle}'
                                : 'Standalone Document',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        _buildMatchBadge(isOcr: isOcr, isFuzzy: isFuzzy, colors: colors),
                      ],
                    ),

                    // Highlighted OCR Context Snippet
                    if (match.snippet.isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 5.0,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: colors.divider.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: _buildFuzzyHighlightedText(
                          text: match.snippet,
                          query: searchQuery,
                          baseStyle: AppTypography.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                          highlightColor: colors.accent,
                          textColor: colors.textPrimary,
                          maxLines: 2,
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
    );
  }

  Widget _buildMatchBadge({
    required bool isOcr,
    required bool isFuzzy,
    required AppColors colors,
  }) {
    String label;
    Color badgeColor;

    if (isFuzzy) {
      label = 'Fuzzy Match';
      badgeColor = Colors.orange;
    } else if (isOcr) {
      label = 'OCR Match';
      badgeColor = Colors.green;
    } else {
      label = 'Title Match';
      badgeColor = colors.accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5.0,
        vertical: 1.0,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildFuzzyHighlightedText({
    required String text,
    required String? query,
    required TextStyle baseStyle,
    required Color highlightColor,
    required Color textColor,
    int maxLines = 1,
  }) {
    if (query == null || query.trim().isEmpty || text.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final eval = FuzzySearchEngine.evaluate(
      query: query,
      text: text,
    );

    if (!eval.hasMatch || eval.highlightSpans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Sort and merge overlapping spans
    final sortedSpans = [...eval.highlightSpans]
      ..sort((a, b) => a.start.compareTo(b.start));

    final mergedSpans = <TokenSpan>[];
    for (final span in sortedSpans) {
      if (span.start < 0 || span.end > text.length || span.start >= span.end) continue;
      if (mergedSpans.isEmpty) {
        mergedSpans.add(span);
      } else {
        final last = mergedSpans.last;
        if (span.start <= last.end) {
          mergedSpans[mergedSpans.length - 1] = TokenSpan(
            start: last.start,
            end: span.end > last.end ? span.end : last.end,
            isExact: last.isExact && span.isExact,
          );
        } else {
          mergedSpans.add(span);
        }
      }
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final span in mergedSpans) {
      if (span.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, span.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: baseStyle.copyWith(
          color: textColor,
          backgroundColor: span.isExact
              ? highlightColor.withValues(alpha: 0.35)
              : Colors.orange.withValues(alpha: 0.28),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = span.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      semanticsLabel: text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
