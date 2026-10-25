import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/application/sample_notes.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

class OnboardingPersonalizeControls extends ConsumerStatefulWidget {
  const OnboardingPersonalizeControls({super.key});

  @override
  ConsumerState<OnboardingPersonalizeControls> createState() =>
      _OnboardingPersonalizeControlsState();
}

class _OnboardingPersonalizeControlsState
    extends ConsumerState<OnboardingPersonalizeControls> {
  bool _sampleLoading = false;
  bool _sampleLoaded = false;
  bool _sampleError = false;

  Future<void> _handleLoadSampleNotes() async {
    if (_sampleLoading) return;
    setState(() {
      _sampleLoading = true;
      _sampleError = false;
    });

    try {
      final repository = ref.read(notesRepositoryProvider);
      await SampleNotes.populateSampleNotes(repository);
      ref.read(notesCollectionProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _sampleLoading = false;
          _sampleLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sampleLoading = false;
          _sampleError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final themeSettings = ref.watch(themeSettingsProvider);
    final activeNotesCountAsync = ref.watch(activeNotesCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // PAPER STYLE
              // ==========================================
              _buildSectionLabel('PAPER STYLE', colors),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildPaperCard(
                      key: const Key('onboarding-paper-classic'),
                      title: 'Classic Paper',
                      description: 'Warm terracotta on soft paper.',
                      isSelected:
                          themeSettings.family == ThemeFamily.classicPaper,
                      swatches: isDark
                          ? [
                              AppColors.classicDark.background,
                              AppColors.classicDark.surface,
                              AppColors.classicDark.accent,
                            ]
                          : [
                              AppColors.classicLight.background,
                              AppColors.classicLight.surface,
                              AppColors.classicLight.accent,
                            ],
                      colors: colors,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.classicPaper);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaperCard(
                      key: const Key('onboarding-paper-warm'),
                      title: 'Warm Paper',
                      description: 'Ivory and slate with a calm blue accent.',
                      isSelected:
                          themeSettings.family == ThemeFamily.warmPaper,
                      swatches: isDark
                          ? [
                              AppColors.midnightPaperDark.background,
                              AppColors.midnightPaperDark.surface,
                              AppColors.midnightPaperDark.accent,
                            ]
                          : [
                              AppColors.warmPaperLight.background,
                              AppColors.warmPaperLight.surface,
                              AppColors.warmPaperLight.accent,
                            ],
                      colors: colors,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.warmPaper);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ==========================================
              // APPEARANCE
              // ==========================================
              _buildSectionLabel('APPEARANCE', colors),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAppearanceSegment(
                        key: const Key('onboarding-appearance-system'),
                        icon: Icons.brightness_auto_rounded,
                        label: 'System',
                        isSelected:
                            themeSettings.appearance == AppearanceMode.system,
                        colors: colors,
                        onTap: () {
                          ref
                              .read(themeSettingsProvider.notifier)
                              .setAppearanceMode(AppearanceMode.system);
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildAppearanceSegment(
                        key: const Key('onboarding-appearance-light'),
                        icon: Icons.light_mode_outlined,
                        label: 'Light',
                        isSelected:
                            themeSettings.appearance == AppearanceMode.light,
                        colors: colors,
                        onTap: () {
                          ref
                              .read(themeSettingsProvider.notifier)
                              .setAppearanceMode(AppearanceMode.light);
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildAppearanceSegment(
                        key: const Key('onboarding-appearance-dark'),
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark',
                        isSelected:
                            themeSettings.appearance == AppearanceMode.dark,
                        colors: colors,
                        onTap: () {
                          ref
                              .read(themeSettingsProvider.notifier)
                              .setAppearanceMode(AppearanceMode.dark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // SAMPLE NOTES
              // ==========================================
              _buildSectionLabel('SAMPLE NOTES', colors),
              const SizedBox(height: 10),
              _buildSampleNotesSection(
                colors: colors,
                activeCountAsync: activeNotesCountAsync,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Change any of this later in Settings.',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textTertiary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, AppColors colors) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: colors.textTertiary,
      ),
    );
  }

  Widget _buildPaperCard({
    required Key key,
    required String title,
    required String description,
    required bool isSelected,
    required List<Color> swatches,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSoft : colors.background,
            borderRadius: BorderRadius.circular(12),
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
                  // 3-dot swatches
                  Row(
                    children: [
                      for (final c in swatches) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.divider,
                              width: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textTertiary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSegment({
    required Key key,
    required IconData icon,
    required String label,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? colors.accentDark : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.accentDark : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSampleNotesSection({
    required AppColors colors,
    required AsyncValue<int> activeCountAsync,
  }) {
    // 1. Loading state
    if (activeCountAsync.isLoading) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }

    final count = activeCountAsync.valueOrNull ?? 0;

    // 2. Samples loaded in this session or active count > 0
    if (_sampleLoaded || count > 0) {
      final bool justLoaded = _sampleLoaded;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: colors.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    justLoaded
                        ? 'Sample notes are on the desk.'
                        : 'Your desk already has notes.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    justLoaded
                        ? 'Five little examples, ready to poke around in.'
                        : "We'll leave your library just as it is.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 3. Library empty (count == 0), not loaded yet
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few notes to start with?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Five examples of Markdown, tags, checklists, and editorial formatting.',
          style: TextStyle(
            fontSize: 11.5,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        QuietButton(
          key: const Key('onboarding-sample-load'),
          label: 'Leave sample notes',
          icon: Icons.auto_stories_outlined,
          variant: QuietButtonVariant.secondary,
          isLoading: _sampleLoading,
          onPressed: _sampleLoading ? null : _handleLoadSampleNotes,
        ),
        if (_sampleError) ...[
          const SizedBox(height: 8),
          Text(
            "Couldn't load the sample notes. You can try again from Settings → Advanced.",
            style: TextStyle(
              fontSize: 11.5,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }
}
