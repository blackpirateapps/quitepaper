import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import '../application/settings_provider.dart';
import '../application/typography_provider.dart';
import 'typography_settings_screen.dart';
import 'widgets/settings_shared_widgets.dart';

/// Screen allowing the user to configure themes, dark mode, and typography.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final themeSettings = ref.watch(themeSettingsProvider);
    final typographySettings = ref.watch(typographySettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Appearance',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // ==========================================
                // Section: Theme Family
                // ==========================================
                buildSectionHeader(context, 'THEME FAMILY'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Classic Paper',
                      subtitle:
                          'Warm terracotta & soft paper editorial tones',
                      trailing: buildThemePreviewSwatches(
                        context: context,
                        colors: isDark
                            ? AppColors.classicDark
                            : AppColors.classicLight,
                        isSelected:
                            themeSettings.family == ThemeFamily.classicPaper,
                      ),
                      isSelected:
                          themeSettings.family == ThemeFamily.classicPaper,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.classicPaper);
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Warm Paper',
                      subtitle:
                          'Warm ivory & midnight slate with serene slate blue accent',
                      trailing: buildThemePreviewSwatches(
                        context: context,
                        colors: isDark
                            ? AppColors.midnightPaperDark
                            : AppColors.warmPaperLight,
                        isSelected:
                            themeSettings.family == ThemeFamily.warmPaper,
                      ),
                      isSelected:
                          themeSettings.family == ThemeFamily.warmPaper,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.warmPaper);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Appearance
                // ==========================================
                buildSectionHeader(context, 'APPEARANCE'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.brightness_auto_rounded,
                      title: 'System',
                      subtitle: 'Matches your device display settings',
                      isSelected:
                          themeSettings.appearance == AppearanceMode.system,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.system);
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.light_mode_outlined,
                      title: 'Light',
                      isSelected:
                          themeSettings.appearance == AppearanceMode.light,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.light);
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark',
                      isSelected:
                          themeSettings.appearance == AppearanceMode.dark,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.dark);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Typography
                // ==========================================
                buildSectionHeader(context, 'TYPOGRAPHY'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.text_fields_rounded,
                      title: 'Typography',
                      subtitle: 'Body font and font size',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${typographySettings.bodyFontFamily ?? 'System'}, ${typographySettings.fontSize.toInt()}pt',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const TypographySettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
