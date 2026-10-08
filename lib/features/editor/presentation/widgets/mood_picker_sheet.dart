import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_mood.dart';

/// Modal bottom sheet allowing users to pick a 1-to-10 mood level or clear it.
class MoodPickerSheet extends StatelessWidget {
  const MoodPickerSheet({
    super.key,
    this.currentMood,
    required this.onMoodSelected,
    required this.onMoodCleared,
  });

  final int? currentMood;
  final ValueChanged<int> onMoodSelected;
  final VoidCallback onMoodCleared;

  static Future<void> show({
    required BuildContext context,
    required int? currentMood,
    required ValueChanged<int> onMoodSelected,
    required VoidCallback onMoodCleared,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => MoodPickerSheet(
        currentMood: currentMood,
        onMoodSelected: onMoodSelected,
        onMoodCleared: onMoodCleared,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
                Icon(Icons.sentiment_satisfied_outlined, size: 18, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Record Mood',
                  style: AppTypography.headline.copyWith(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (currentMood != null)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onMoodCleared();
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
            const SizedBox(height: AppSpacing.md),

            // 10 mood levels
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: JournalMood.levels.map((item) {
                final isSelected = currentMood == item.level;
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () {
                    Navigator.of(context).pop();
                    onMoodSelected(item.level);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accent.withValues(alpha: 0.15)
                          : colors.surfaceSubtle.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: isSelected
                            ? colors.accent
                            : colors.divider.withValues(alpha: 0.5),
                        width: isSelected ? 1.4 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          '${item.level}',
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? colors.accent : colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          item.label,
                          style: AppTypography.caption.copyWith(
                            color: isSelected ? colors.textPrimary : colors.textTertiary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
