import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_moment.dart';

/// Modal bottom sheet for choosing or clearing a journal entry's moment context.
class MomentPickerSheet extends StatelessWidget {
  const MomentPickerSheet({
    super.key,
    this.currentMoment,
    required this.onMomentSelected,
    required this.onMomentCleared,
  });

  final String? currentMoment;
  final ValueChanged<String> onMomentSelected;
  final VoidCallback onMomentCleared;

  static Future<void> show({
    required BuildContext context,
    required String? currentMoment,
    required ValueChanged<String> onMomentSelected,
    required VoidCallback onMomentCleared,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MomentPickerSheet(
        currentMoment: currentMoment,
        onMomentSelected: onMomentSelected,
        onMomentCleared: onMomentCleared,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final normalizedCurrent = currentMoment?.trim().toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        border: Border(
          top: BorderSide(color: colors.divider.withValues(alpha: 0.7), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Select Moment',
                  style: AppTypography.headline.copyWith(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (normalizedCurrent != null && normalizedCurrent.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMomentCleared();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Clear',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 10 moments in a structured list / grid
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: JournalMoment.all.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: colors.divider.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final moment = JournalMoment.all[index];
                  final isSelected = normalizedCurrent == moment.key;

                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: () {
                      Navigator.of(context).pop();
                      onMomentSelected(moment.key);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.accent.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.accent.withValues(alpha: 0.2)
                                  : colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Icon(
                              moment.icon,
                              size: 16,
                              color: isSelected ? colors.accent : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  moment.label,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isSelected ? colors.accent : colors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  moment.description,
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textTertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_rounded, size: 16, color: colors.accent),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
