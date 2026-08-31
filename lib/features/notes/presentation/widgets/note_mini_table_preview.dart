import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/note_metadata_extractor.dart';

/// Compact, calm mini table preview widget rendered directly in note list tiles
/// in place of raw canonical Markdown table syntax.
class NoteMiniTablePreview extends StatelessWidget {
  const NoteMiniTablePreview({
    super.key,
    required this.table,
  });

  final NoteTablePreview table;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final colCount = table.headers.length;
    if (colCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 3.0, bottom: 2.0),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              border: Border(
                bottom: BorderSide(
                  color: colors.divider.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: List.generate(colCount, (cIdx) {
                final isLast = cIdx == colCount - 1;
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: isLast
                        ? null
                        : BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: colors.divider.withValues(alpha: 0.4),
                                width: 0.6,
                              ),
                            ),
                          ),
                    child: Text(
                      table.headers[cIdx],
                      style: AppTypography.caption.copyWith(
                        color: colors.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            ),
          ),

          // 2. Data Rows (at most 2 rows)
          ...table.rows.take(2).map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.divider.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: List.generate(colCount, (cIdx) {
                  final text = cIdx < row.length ? row[cIdx] : '';
                  final isLast = cIdx == colCount - 1;
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      decoration: isLast
                          ? null
                          : BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: colors.divider.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                            ),
                      child: Text(
                        text,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
