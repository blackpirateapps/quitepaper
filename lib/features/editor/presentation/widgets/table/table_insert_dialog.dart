import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/widgets/quiet_button.dart';

/// Modal dialog for configuring and inserting a new Markdown table.
class TableInsertDialog extends StatefulWidget {
  const TableInsertDialog({
    super.key,
    this.initialRows = 3,
    this.initialColumns = 3,
  });

  final int initialRows;
  final int initialColumns;

  static Future<({int rows, int columns})?> show(
    BuildContext context, {
    int initialRows = 3,
    int initialColumns = 3,
  }) {
    return showDialog<({int rows, int columns})>(
      context: context,
      builder: (context) => TableInsertDialog(
        initialRows: initialRows,
        initialColumns: initialColumns,
      ),
    );
  }

  @override
  State<TableInsertDialog> createState() => _TableInsertDialogState();
}

class _TableInsertDialogState extends State<TableInsertDialog> {
  late int _rows;
  late int _columns;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows;
    _columns = widget.initialColumns;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.table_chart_outlined,
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Insert Table',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Select the initial grid dimensions for your Markdown table:',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Columns Stepper
              _buildStepper(
                label: 'Columns',
                value: _columns,
                min: 1,
                max: 12,
                onChanged: (val) => setState(() => _columns = val),
                colors: colors,
              ),
              const SizedBox(height: AppSpacing.md),

              // Rows Stepper
              _buildStepper(
                label: 'Body Rows',
                value: _rows,
                min: 1,
                max: 30,
                onChanged: (val) => setState(() => _rows = val),
                colors: colors,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: QuietButton(
                      label: 'Cancel',
                      variant: QuietButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: QuietButton(
                      label: 'Insert ($_columns×${_rows + 1})',
                      variant: QuietButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(context).pop((rows: _rows, columns: _columns));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required AppColors colors,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: AppRadii.borderMd,
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                color: value > min ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                color: value < max ? colors.textPrimary : colors.textTertiary.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
