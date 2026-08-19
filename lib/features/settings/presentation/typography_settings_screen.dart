import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/domain/markdown_styles.dart';
import '../../editor/application/markdown_parser.dart';
import '../application/typography_provider.dart';
import '../domain/typography_settings.dart';
import 'widgets/font_picker_sheet.dart';

class TypographySettingsScreen extends ConsumerWidget {
  const TypographySettingsScreen({super.key});

  static const String _sampleMarkdown = '''# The Quiet Art
Typography is two-dimensional architecture.

## Principles of Layout
Good design is as little design as possible. **Bold ideas** and *delicate details* create quiet harmony.

- [x] Clear visual hierarchy
- [ ] Balanced letterforms

> Simplicity is the ultimate sophistication.

```dart
void compose() => print('Quiet Paper');
```''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final notifier = ref.read(typographySettingsProvider.notifier);

    final markdownStyles = MarkdownStyles.fromColors(
      colors,
      typography: typography,
    );

    final styledTextSpan = MarkdownParser.buildTextSpan(
      text: _sampleMarkdown,
      styles: markdownStyles,
    );

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
          'Typography',
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
            child: Column(
              children: [
                // ==========================================
                // Sticky / Pinned Markdown Live Preview
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtle preview header bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.5),
                            border: Border(
                              bottom: BorderSide(
                                color: colors.divider.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE PREVIEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Scrollable preview content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: AppSpacing.md + typography.paragraphIndent,
                              right: AppSpacing.md,
                              top: AppSpacing.sm,
                              bottom: AppSpacing.sm,
                            ),
                            physics: const BouncingScrollPhysics(),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: typography.paragraphWidth.maxWidth,
                                ),
                                child: Text.rich(
                                  styledTextSpan,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ==========================================
                // Scrollable Controls
                // ==========================================
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    children: [
                      // ------------------------------------------
                      // Group 1 (Typefaces)
                      // ------------------------------------------
                      _buildSectionHeader(context, 'Typefaces'),
                      _SettingsGroup(
                        children: [
                          _FontPickerRow(
                            label: 'Heading Font',
                            selectedFont: typography.headingFontFamily ??
                                CuratedFonts.systemSans,
                            onTap: () {
                              FontPickerSheet.show(
                                context,
                                title: 'Heading Font',
                                currentFont: typography.headingFontFamily,
                                type: FontPickerType.heading,
                                onFontSelected: notifier.setHeadingFontFamily,
                              );
                            },
                          ),
                          _buildDivider(colors),
                          _FontPickerRow(
                            label: 'Body Font',
                            selectedFont: typography.bodyFontFamily ??
                                CuratedFonts.systemSans,
                            onTap: () {
                              FontPickerSheet.show(
                                context,
                                title: 'Body Font',
                                currentFont: typography.bodyFontFamily,
                                type: FontPickerType.body,
                                onFontSelected: notifier.setBodyFontFamily,
                              );
                            },
                          ),
                          _buildDivider(colors),
                          _FontPickerRow(
                            label: 'Code Font',
                            selectedFont: typography.codeFontFamily ??
                                CuratedFonts.systemMono,
                            onTap: () {
                              FontPickerSheet.show(
                                context,
                                title: 'Code Font',
                                currentFont: typography.codeFontFamily,
                                type: FontPickerType.code,
                                onFontSelected: notifier.setCodeFontFamily,
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ------------------------------------------
                      // Group 2 (Dimensions)
                      // ------------------------------------------
                      _buildSectionHeader(context, 'Dimensions'),
                      _SettingsGroup(
                        children: [
                          _SliderRow(
                            label: 'Font Size',
                            valueLabel: '${typography.fontSize.toInt()} pt',
                            value: typography.fontSize,
                            min: 12.0,
                            max: 32.0,
                            divisions: 20,
                            onChanged: notifier.setFontSize,
                          ),
                          _buildDivider(colors),
                          _SliderRow(
                            label: 'Line Height',
                            valueLabel:
                                '${typography.lineHeight.toStringAsFixed(1)}x',
                            value: typography.lineHeight,
                            min: 1.0,
                            max: 2.5,
                            divisions: 15,
                            onChanged: notifier.setLineHeight,
                          ),
                          _buildDivider(colors),
                          _SliderRow(
                            label: 'Letter Spacing',
                            valueLabel:
                                '${typography.letterSpacing.toStringAsFixed(1)} px',
                            value: typography.letterSpacing,
                            min: -1.0,
                            max: 2.0,
                            divisions: 30,
                            onChanged: notifier.setLetterSpacing,
                          ),
                          _buildDivider(colors),
                          _SliderRow(
                            label: 'Paragraph Indent',
                            valueLabel:
                                '${typography.paragraphIndent.toInt()} px',
                            value: typography.paragraphIndent,
                            min: 0.0,
                            max: 40.0,
                            divisions: 40,
                            onChanged: notifier.setParagraphIndent,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ------------------------------------------
                      // Group 3 (Layout & Actions)
                      // ------------------------------------------
                      _buildSectionHeader(context, 'Layout & Actions'),
                      _SettingsGroup(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Paragraph Width',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                CupertinoSlidingSegmentedControl<ParagraphWidth>(
                                  groupValue: typography.paragraphWidth,
                                  backgroundColor: colors.background,
                                  thumbColor: colors.surface,
                                  children: {
                                    ParagraphWidth.narrow: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(
                                        'Narrow',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: typography.paragraphWidth ==
                                                  ParagraphWidth.narrow
                                              ? colors.accent
                                              : colors.textSecondary,
                                          fontWeight:
                                              typography.paragraphWidth ==
                                                      ParagraphWidth.narrow
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    ParagraphWidth.medium: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(
                                        'Medium',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: typography.paragraphWidth ==
                                                  ParagraphWidth.medium
                                              ? colors.accent
                                              : colors.textSecondary,
                                          fontWeight:
                                              typography.paragraphWidth ==
                                                      ParagraphWidth.medium
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    ParagraphWidth.full: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text(
                                        'Full',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: typography.paragraphWidth ==
                                                  ParagraphWidth.full
                                              ? colors.accent
                                              : colors.textSecondary,
                                          fontWeight:
                                              typography.paragraphWidth ==
                                                      ParagraphWidth.full
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  },
                                  onValueChanged: (val) {
                                    if (val != null) {
                                      notifier.setParagraphWidth(val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          _buildDivider(colors),
                          // Reset to Default Row
                          InkWell(
                            onTap: () {
                              notifier.resetToDefault();
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Typography reset to factory defaults'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: Text(
                                'Reset to Default',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Divider(
        height: 1,
        thickness: 1,
        color: colors.divider.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _FontPickerRow extends StatelessWidget {
  const _FontPickerRow({
    required this.label,
    required this.selectedFont,
    required this.onTap,
  });

  final String label;
  final String selectedFont;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              selectedFont,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                fontFamily: (selectedFont == 'System Sans' ||
                        selectedFont == 'System Serif' ||
                        selectedFont == 'Monospace')
                    ? null
                    : selectedFont,
              ),
            ),
            const SizedBox(width: 6),
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
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: 10,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.accent,
              inactiveTrackColor: colors.divider.withValues(alpha: 0.5),
              thumbColor: colors.accent,
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
