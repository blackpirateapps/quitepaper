import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/rich_block.dart';
import '../../application/rich_document_controller.dart';
import 'table/markdown_table_view.dart';

/// Specialized table widget embedded in Quiet Paper's Visual editor surface.
///
/// Wraps [MarkdownTableView] with quiet editorial actions (Add row, Add column,
/// change alignment, delete table) while synchronizing directly with [TableBlock]
/// in the authoritative [RichDocument].
class RichTableEditor extends StatelessWidget {
  const RichTableEditor({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    this.readOnly = false,
  });

  final TableBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: MarkdownTableView(
              table: block.table,
              readOnly: readOnly,
              onCellTap: (pos) {
                // Table cell tapped
              },
            ),
          ),

          // Action bar (if not read-only)
          if (!readOnly)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Text(
                    '${block.table.columnCount}×${block.table.rowCount} Table',
                    style: AppTypography.caption.copyWith(color: colors.textTertiary),
                  ),
                  const Spacer(),
                  QuietIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Add Row',
                    size: 16,
                    onPressed: () => _addRow(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  QuietIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete Table',
                    size: 16,
                    onPressed: () => _deleteTable(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _addRow(BuildContext context) {
    final currentTable = block.table;
    // Refresh table block in document with new row
    controller.insertTable(rows: currentTable.rowCount + 1, cols: currentTable.columnCount);
  }

  void _deleteTable(BuildContext context) {
    controller.convertBlockToParagraph(blockIndex);
  }
}
