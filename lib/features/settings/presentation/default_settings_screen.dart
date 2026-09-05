import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../application/default_settings_provider.dart';

/// Screen allowing the user to configure default behaviors and gestures.
class DefaultSettingsScreen extends ConsumerWidget {
  const DefaultSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final settings = ref.watch(defaultSettingsProvider);
    final notifier = ref.read(defaultSettingsProvider.notifier);

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
          'Default Settings',
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
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl,
              ),
              children: [
                _buildSectionHeader('GESTURES & SEARCH', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildSwitchRow(
                      context: context,
                      colors: colors,
                      icon: Icons.find_in_page_outlined,
                      title: 'Swipe to Search in Editor',
                      subtitle:
                          'Pull down at the top of a note to reveal in-note search',
                      value: settings.swipeToSearchEditor,
                      onChanged: (val) => notifier.setSwipeToSearchEditor(val),
                    ),
                    _buildDivider(colors),
                    _buildSwitchRow(
                      context: context,
                      colors: colors,
                      icon: Icons.manage_search_rounded,
                      title: 'Swipe Down to Search in Notes List',
                      subtitle:
                          'Pull down at the top of the notes list to reveal search',
                      value: settings.swipeDownToSearchNotes,
                      onChanged: (val) => notifier.setSwipeDownToSearchNotes(val),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text(
                    'When search gestures are turned off, search remains accessible via toolbar buttons and keyboard shortcuts (Ctrl+F / ⌘F).',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.0,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildGroupCard({
    required AppColors colors,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      color: colors.divider.withValues(alpha: 0.5),
      height: 1,
      thickness: 1.0,
      indent: 52, // 16 horizontal padding + 24 icon box + 12 gap = 52
      endIndent: 0,
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.0,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          CupertinoSwitch(
            value: value,
            activeTrackColor: colors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
