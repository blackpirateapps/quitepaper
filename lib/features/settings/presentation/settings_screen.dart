import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/sample_notes.dart';
import '../application/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            // Section: Appearance
            Text(
              'Appearance',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                children: [
                  _ThemeOptionTile(
                    title: 'System default',
                    icon: Icons.brightness_auto_rounded,
                    isSelected: currentTheme == ThemeMode.system,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system);
                    },
                  ),
                  Divider(color: colors.divider, height: 1),
                  _ThemeOptionTile(
                    title: 'Light paper',
                    icon: Icons.light_mode_outlined,
                    isSelected: currentTheme == ThemeMode.light,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light);
                    },
                  ),
                  Divider(color: colors.divider, height: 1),
                  _ThemeOptionTile(
                    title: 'Dark paper',
                    icon: Icons.dark_mode_outlined,
                    isSelected: currentTheme == ThemeMode.dark,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: Sample Data
            Text(
              'Sample Notes',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Populate example notes demonstrating Markdown, hashtags, and editorial formatting.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  QuietButton(
                    label: 'Load sample notes',
                    icon: Icons.auto_stories_rounded,
                    variant: QuietButtonVariant.secondary,
                    onPressed: () async {
                      final repository = ref.read(notesRepositoryProvider);
                      await SampleNotes.populateSampleNotes(repository);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sample notes loaded'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: About
            Text(
              'About',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiet Paper',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A quiet place to think.',
                    style: AppTypography.body.copyWith(
                      color: colors.accentDark,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Version 1.0.0 • Offline-first • Markdown notes',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14.0,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.accent : colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected ? colors.accent : colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
