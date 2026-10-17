import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/tag_colors.dart';

/// Modal bottom sheet for choosing or clearing a tag's color accent.
class TagColorPickerSheet extends StatelessWidget {
  const TagColorPickerSheet({
    super.key,
    required this.selectedColorId,
    required this.onColorSelected,
  });

  final String? selectedColorId;
  final ValueChanged<String?> onColorSelected;

  static Future<String?> show(
    BuildContext context, {
    String? currentColorId,
    GlobalKey? anchorKey,
  }) {
    return QuietAdaptiveModal.show<String?>(
      context: context,
      type: AdaptiveModalType.popover,
      anchorKey: anchorKey,
      maxWidth: 380,
      builder: (ctx) => TagColorPickerSheet(
        selectedColorId: currentColorId,
        onColorSelected: (colorId) => Navigator.of(ctx).pop(colorId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = PlatformLayoutHelper.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isDesktop
            ? AppRadii.borderMd
            : const BorderRadius.vertical(top: AppRadii.rLg),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdaptiveSheetDragHandle(),

              // Header
              Row(
                children: [
                  Text(
                    'Tag Color',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  QuietIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // "Default / None" option
              InkWell(
                onTap: () => onColorSelected(null),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: selectedColorId == null
                        ? colors.tagBackground
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: selectedColorId == null
                          ? colors.accent
                          : colors.divider.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.textTertiary, width: 1.5),
                        ),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 2,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'None (Default Paper Accent)',
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: selectedColorId == null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedColorId == null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: colors.accent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'WARM EDITORIAL PALETTE',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Swatches Grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: TagColors.all.map((colorDef) {
                  final isSelected = selectedColorId == colorDef.id;
                  final fg = colorDef.foreground(isDark);
                  final bg = colorDef.background(isDark);

                  return InkWell(
                    onTap: () => onColorSelected(colorDef.id),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Container(
                      width: 76,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? bg : colors.background,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: isSelected
                              ? fg
                              : colors.divider.withValues(alpha: 0.6),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: fg,
                              shape: BoxShape.circle,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            colorDef.label,
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? fg : colors.textSecondary,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
