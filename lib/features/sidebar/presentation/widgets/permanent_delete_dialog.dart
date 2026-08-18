import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

class PermanentDeleteDialog extends StatelessWidget {
  const PermanentDeleteDialog({
    super.key,
    this.count = 1,
  });

  final int count;

  static Future<bool> show(BuildContext context, {int count = 1}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PermanentDeleteDialog(count: count),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMultiple = count > 1;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.rLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
      title: Text(
        isMultiple ? 'Delete $count notes permanently?' : 'Delete permanently?',
        style: AppTypography.headline.copyWith(
          color: colors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        isMultiple
            ? 'These notes will be permanently deleted.\nThis action cannot be undone.'
            : 'This note will be permanently deleted.\nThis action cannot be undone.',
        style: AppTypography.bodySmall.copyWith(
          color: colors.textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        QuietButton(
          label: 'Cancel',
          variant: QuietButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: AppSpacing.xs),
        QuietButton(
          label: 'Delete Permanently',
          variant: QuietButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
