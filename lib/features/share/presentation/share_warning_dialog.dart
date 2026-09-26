import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';

/// Heads-up dialog shown before a note is shared as a public URL.
///
/// Sharing removes end-to-end encryption for the note, so the user must
/// explicitly accept that its content and attachments are uploaded UNENCRYPTED
/// to the app owner's server. Returns `true` if the user accepts.
class ShareWarningDialog extends StatelessWidget {
  const ShareWarningDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => const ShareWarningDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.rLg),
      ),
      titlePadding:
          const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Share as a public link?',
              style: AppTypography.headline.copyWith(
                color: colors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This note and its attachments will be uploaded UNENCRYPTED to the '
            'app owner\'s server so anyone with the link can read them.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            'A password protects only the page text. Images and files stay '
            'reachable by their (unguessable) URL. Shares expire automatically '
            'after 30 days, and you can delete a share at any time.',
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        QuietButton(
          label: 'Cancel',
          variant: QuietButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: AppSpacing.xs),
        QuietButton(
          label: 'Continue',
          variant: QuietButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
