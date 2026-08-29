import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../application/markdown_parser.dart';
import '../../../domain/markdown_styles.dart';
import '../../../domain/markdown_table.dart';
import '../../../domain/markdown_table_cell.dart';
import '../../../domain/markdown_table_position.dart';

/// Renders a lightweight, visually styled Markdown table.
/// Used for inactive tables and read-only preview mode.
class MarkdownTableView extends StatelessWidget {
  const MarkdownTableView({
    super.key,
    required this.table,
    this.styles,
    this.onCellTap,
    this.readOnly = false,
    this.searchQuery,
  });

  final MarkdownTable table;
  final MarkdownStyles? styles;
  final ValueChanged<TablePosition>? onCellTap;
  final bool readOnly;
  final String? searchQuery;

  static const double _columnWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveStyles = styles ?? MarkdownStyles.fromColors(colors);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              _buildRow(
                context: context,
                row: table.headerRow,
                rowIndex: 0,
                isHeader: true,
                colors: colors,
                styles: effectiveStyles,
              ),

              // Body Rows
              for (var r = 0; r < table.bodyRows.length; r++) ...[
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: colors.divider.withValues(alpha: 0.5),
                ),
                _buildRow(
                  context: context,
                  row: table.bodyRows[r],
                  rowIndex: r + 1,
                  isHeader: false,
                  colors: colors,
                  styles: effectiveStyles,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required dynamic row,
    required int rowIndex,
    required bool isHeader,
    required AppColors colors,
    required MarkdownStyles styles,
  }) {
    final cells = row.cells as List<MarkdownTableCell>;

    return Container(
      color: isHeader ? colors.tagBackground.withValues(alpha: 0.35) : Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var col = 0; col < table.columnCount; col++) ...[
            if (col > 0)
              Container(
                width: 1.0,
                color: colors.divider.withValues(alpha: 0.4),
              ),
            _buildCell(
              context: context,
              cell: col < cells.length ? cells[col] : null,
              rowIndex: rowIndex,
              columnIndex: col,
              isHeader: isHeader,
              colors: colors,
              styles: styles,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCell({
    required BuildContext context,
    required MarkdownTableCell? cell,
    required int rowIndex,
    required int columnIndex,
    required bool isHeader,
    required AppColors colors,
    required MarkdownStyles styles,
  }) {
    final cellText = cell?.trimmedText ?? '';
    final alignment = table.getAlignment(columnIndex);
    final pos = TablePosition(row: rowIndex, column: columnIndex);

    final textSpan = cellText.isNotEmpty
        ? MarkdownParser.buildTextSpan(
            text: cellText,
            styles: styles,
            searchQuery: searchQuery,
          )
        : TextSpan(
            text: isHeader ? 'Header ${columnIndex + 1}' : ' ',
            style: isHeader
                ? AppTypography.bodySmallMedium.copyWith(
                    color: colors.textTertiary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  )
                : AppTypography.bodySmall.copyWith(color: colors.textTertiary),
          );

    final contentWidget = Container(
      width: _columnWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      alignment: alignment.alignment,
      child: RichText(
        text: textSpan,
        textAlign: alignment.textAlign,
        overflow: TextOverflow.clip,
      ),
    );

    if (readOnly || onCellTap == null) {
      return contentWidget;
    }

    return InkWell(
      onTap: () => onCellTap?.call(pos),
      splashColor: colors.accent.withValues(alpha: 0.1),
      highlightColor: colors.accent.withValues(alpha: 0.05),
      child: contentWidget,
    );
  }
}
