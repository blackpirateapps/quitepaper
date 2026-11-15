import '../../../application/markdown_table_parser.dart';
import '../../../application/smart_table_display.dart';
import '../../../application/smart_table_edits.dart';
import '../../../application/smart_table_markdown.dart';
import '../../../domain/smart_tables/formula_engine.dart';
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
class MarkdownTableView extends StatefulWidget {
  const MarkdownTableView({
    super.key,
    required this.table,
    this.styles,
    this.onCellTap,
    this.readOnly = false,
    this.searchQuery,
    this.sourceMarkdown,
  });

  final MarkdownTable table;
  final String? sourceMarkdown;
  final MarkdownStyles? styles;
  final ValueChanged<TablePosition>? onCellTap;
  final bool readOnly;
  final String? searchQuery;

  @override
  State<MarkdownTableView> createState() => _MarkdownTableViewState();
}

class _MarkdownTableViewState extends State<MarkdownTableView> {
  MarkdownTable get table => widget.table;
  MarkdownStyles? get styles => widget.styles;
  ValueChanged<TablePosition>? get onCellTap => widget.onCellTap;
  bool get readOnly => widget.readOnly;
  String? get searchQuery => widget.searchQuery;
  late FormulaEngine _engine;
  Map<String, dynamic> _formats = {};
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(MarkdownTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table ||
        oldWidget.sourceMarkdown != widget.sourceMarkdown) {
      _refresh();
    }
  }

  void _refresh() {
    _engine = FormulaEngine(tableRawCells(table));
    final source = widget.sourceMarkdown ?? table.rawMarkdown;
    final projection = widget.sourceMarkdown == null
        ? const MarkdownTableParser().findTables(source).first
        : table;
    _formats = SmartTableMetadata.read(source, projection).section('formats');
  }

  static const double _columnWidth = 140.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveStyles = styles ?? MarkdownStyles.fromColors(colors);
    final engine = _engine;

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
                engine: engine,
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
                  engine: engine,
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
    required FormulaEngine engine,
  }) {
    final cells = row.cells as List<MarkdownTableCell>;

    return Container(
      color: isHeader
          ? colors.tagBackground.withValues(alpha: 0.35)
          : Colors.transparent,
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
              engine: engine,
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
    required FormulaEngine engine,
  }) {
    final raw = cell?.trimmedText ?? '';
    final config = _formats['$columnIndex'];
    final cellText =
        config != null || raw.startsWith('=') || raw.startsWith("'=")
        ? SmartTableDisplay.format(
            engine.value(rowIndex, columnIndex),
            config,
            locale: Localizations.localeOf(context).toString(),
          )
        : raw;
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
      return Semantics(
        label:
            'Row ${rowIndex + 1}, column ${columnIndex + 1}, $cellText${raw.startsWith('=') ? ', formula $raw' : ''}',
        child: contentWidget,
      );
    }

    return InkWell(
      onTap: () => onCellTap?.call(pos),
      splashColor: colors.accent.withValues(alpha: 0.1),
      highlightColor: colors.accent.withValues(alpha: 0.05),
      child: contentWidget,
    );
  }
}
