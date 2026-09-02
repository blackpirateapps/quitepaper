import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../features/tags/domain/phosphor_icons.dart';

/// Modal bottom action sheet presenting heading level operations and semantic actions.
/// Modeled after [MarkdownTableActionSheet] to provide visual and interaction consistency.
class MarkdownHeadingActionSheet extends StatelessWidget {
  const MarkdownHeadingActionSheet({
    super.key,
    required this.currentLevel,
    required this.onSelectLevel,
    this.onConvertToParagraph,
    this.onCycleLevel,
    this.onDeleteHeading,
  });

  /// The active heading level (1 to 6, or 0 if not currently a heading).
  final int currentLevel;

  /// Callback when a level (1..6) is selected.
  final ValueChanged<int> onSelectLevel;

  /// Callback to convert the heading to a normal paragraph block.
  final VoidCallback? onConvertToParagraph;

  /// Callback to cycle to the next heading level.
  final VoidCallback? onCycleLevel;

  /// Callback to delete the heading block.
  final VoidCallback? onDeleteHeading;

  static Future<void> show(
    BuildContext context, {
    required int currentLevel,
    required ValueChanged<int> onSelectLevel,
    VoidCallback? onConvertToParagraph,
    VoidCallback? onCycleLevel,
    VoidCallback? onDeleteHeading,
  }) {
    final colors = context.appColors;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) => MarkdownHeadingActionSheet(
        currentLevel: currentLevel,
        onSelectLevel: onSelectLevel,
        onConvertToParagraph: onConvertToParagraph,
        onCycleLevel: onCycleLevel,
        onDeleteHeading: onDeleteHeading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final levels = [
      (1, 'H1', 'Title', '30sp bold'),
      (2, 'H2', 'Section', '24sp bold'),
      (3, 'H3', 'Subsection', '20sp bold'),
      (4, 'H4', 'Sub-heading', '17sp medium'),
      (5, 'H5', 'Small', '15sp medium'),
      (6, 'H6', 'Micro', '13sp uppercase'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.textH, size: 18, color: colors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Heading Level',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Heading Levels 2x3 Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _HeadingLevelCard(
                            level: levels[i].$1,
                            tag: levels[i].$2,
                            title: levels[i].$3,
                            subtitle: levels[i].$4,
                            isSelected: currentLevel == levels[i].$1,
                            colors: colors,
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelectLevel(levels[i].$1);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      for (var i = 3; i < 6; i++) ...[
                        if (i > 3) const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _HeadingLevelCard(
                            level: levels[i].$1,
                            tag: levels[i].$2,
                            title: levels[i].$3,
                            subtitle: levels[i].$4,
                            isSelected: currentLevel == levels[i].$1,
                            colors: colors,
                            onTap: () {
                              Navigator.of(context).pop();
                              onSelectLevel(levels[i].$1);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Convert to Paragraph
            if (onConvertToParagraph != null)
              _ActionTile(
                icon: PhosphorIconsRegular.paragraph,
                title: 'Convert to Paragraph (Normal text)',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  onConvertToParagraph!();
                },
              ),

            // Cycle Heading Level
            if (onCycleLevel != null)
              _ActionTile(
                icon: PhosphorIconsRegular.arrowClockwise,
                title: 'Cycle Heading (H1 → H2 → H3)',
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  onCycleLevel!();
                },
              ),

            // Delete Heading Block
            if (onDeleteHeading != null) ...[
              const Divider(height: 16),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete heading',
                isDestructive: true,
                colors: colors,
                onTap: () {
                  Navigator.of(context).pop();
                  onDeleteHeading!();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeadingLevelCard extends StatelessWidget {
  const _HeadingLevelCard({
    required this.level,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final int level;
  final String tag;
  final String title;
  final String subtitle;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.borderSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.14) : colors.background,
          borderRadius: AppRadii.borderSm,
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.accent : colors.tagBackground,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    tag,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? Colors.white : colors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: colors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDestructive ? colors.error : colors.textPrimary;

    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDestructive ? colors.error : colors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: effectiveColor,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
