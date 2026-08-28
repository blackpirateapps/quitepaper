import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';

/// Bottom footer widget for incremental infinite-scroll loading and error recovery
class NotesLoadingMoreIndicator extends StatelessWidget {
  const NotesLoadingMoreIndicator({
    super.key,
    required this.loadingMore,
    required this.error,
    required this.onRetry,
  });

  final bool loadingMore;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (error != null) {
      return Semantics(
        label: 'Could not load more notes. Tap to retry.',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Couldn\'t load more notes',
                    style: AppTypography.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                QuietButton(
                  label: 'Retry',
                  variant: QuietButtonVariant.secondary,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (loadingMore) {
      return Semantics(
        label: 'Loading more notes',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: AppSpacing.xl);
  }
}
