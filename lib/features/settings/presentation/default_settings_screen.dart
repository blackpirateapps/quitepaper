import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../domain/default_settings.dart';
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
                _buildSectionHeader('EDITOR & PREVIEW', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildSwitchRow(
                      context: context,
                      colors: colors,
                      icon: PhosphorIconsRegular.checkSquare,
                      title: 'Interactive Checklists in Preview',
                      subtitle:
                          'Allow checking and unchecking to-do items while in preview mode',
                      value: settings.interactiveChecklistsInPreview,
                      onChanged: (val) =>
                          notifier.setInteractiveChecklistsInPreview(val),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.lg),
                _buildSectionHeader('IMAGE ATTACHMENTS', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildSelectionRow(
                      context: context,
                      colors: colors,
                      icon: PhosphorIconsRegular.fileImage,
                      title: 'Image Compression',
                      subtitle: settings.imageCompressionAction.label,
                      onTap: () => _showActionSelectionSheet(
                        context,
                        ref,
                        settings.imageCompressionAction,
                      ),
                    ),
                    _buildDivider(colors),
                    _buildSelectionRow(
                      context: context,
                      colors: colors,
                      icon: PhosphorIconsRegular.sliders,
                      title: 'Compression Quality',
                      subtitle: settings.imageCompressionPreset.description,
                      onTap: () => _showPresetSelectionSheet(
                        context,
                        ref,
                        settings.imageCompressionPreset,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text(
                    'Images smaller than 500 KB are preserved without compression. Compressed images reduce device storage and end-to-end sync transfer time.',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.0,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildSectionHeader('JOURNAL', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildSwitchRow(
                      context: context,
                      colors: colors,
                      icon: PhosphorIconsRegular.mapPin,
                      title: 'Show place & weather on entries',
                      subtitle:
                          'Display a quiet place and weather line on journal timeline entries',
                      value: settings.showPlaceAndWeatherOnEntries,
                      onChanged: (val) =>
                          notifier.setShowPlaceAndWeatherOnEntries(val),
                    ),
                    _buildDivider(colors),
                    _buildSwitchRow(
                      context: context,
                      colors: colors,
                      icon: PhosphorIconsRegular.plusCircle,
                      title: 'Suggest adding a place to past entries',
                      subtitle:
                          'Offer to add a place when you open a journal entry that has none',
                      value: settings.suggestPlaceForPastEntries,
                      onChanged: (val) =>
                          notifier.setSuggestPlaceForPastEntries(val),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    ImageCompressionAction currentAction,
  ) {
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Default Compression',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (final action in ImageCompressionAction.values) ...[
                ListTile(
                  leading: Icon(
                    action == currentAction
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    color: action == currentAction ? colors.accent : colors.textTertiary,
                    size: 20,
                  ),
                  title: Text(
                    action.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: action == currentAction ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _getActionSubtitle(action),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(defaultSettingsProvider.notifier).setImageCompressionAction(action);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  static String _getActionSubtitle(ImageCompressionAction action) {
    switch (action) {
      case ImageCompressionAction.ask:
        return 'Prompt whenever attaching an image larger than 500 KB';
      case ImageCompressionAction.alwaysCompress:
        return 'Automatically compress images larger than 500 KB';
      case ImageCompressionAction.keepOriginal:
        return 'Always insert full-size images without compressing';
    }
  }

  void _showPresetSelectionSheet(
    BuildContext context,
    WidgetRef ref,
    ImageCompressionPreset currentPreset,
  ) {
    final colors = context.appColors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Compression Quality',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (final preset in ImageCompressionPreset.values) ...[
                ListTile(
                  leading: Icon(
                    preset == currentPreset
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    color: preset == currentPreset ? colors.accent : colors.textTertiary,
                    size: 20,
                  ),
                  title: Text(
                    preset.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: preset == currentPreset ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    preset.description,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(defaultSettingsProvider.notifier).setImageCompressionPreset(preset);
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionRow({
    required BuildContext context,
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
            const SizedBox(width: 8.0),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: colors.textTertiary,
            ),
          ],
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
