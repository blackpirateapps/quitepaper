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
            child: ListView(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: AppSpacing.xxl,
              ),
              children: [
                // ==========================================
                // Group 1: Typefaces
                // ==========================================
                _buildSectionHeader('TYPEFACES', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildFontPickerRow(
                      context: context,
                      colors: colors,
                      title: 'Heading Font',
                      fontFamily: typography.headingFontFamily ?? 'System Sans',
                      onTap: () {
                        FontPickerSheet.show(
                          context,
                          title: 'Heading Font',
                          currentFont: typography.headingFontFamily,
                          type: FontPickerType.heading,
                          onFontSelected: (font) {
                            notifier.setHeadingFontFamily(font);
                          },
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _buildFontPickerRow(
                      context: context,
                      colors: colors,
                      title: 'Body Font',
                      fontFamily: typography.bodyFontFamily ?? 'System Sans',
                      onTap: () {
                        FontPickerSheet.show(
                          context,
                          title: 'Body Font',
                          currentFont: typography.bodyFontFamily,
                          type: FontPickerType.body,
                          onFontSelected: (font) {
                            notifier.setBodyFontFamily(font);
                          },
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _buildFontPickerRow(
                      context: context,
                      colors: colors,
                      title: 'Code Font',
                      fontFamily: typography.codeFontFamily ?? 'monospace',
                      onTap: () {
                        FontPickerSheet.show(
                          context,
                          title: 'Code Font',
                          currentFont: typography.codeFontFamily,
                          type: FontPickerType.code,
                          onFontSelected: (font) {
                            notifier.setCodeFontFamily(font);
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Group 2: Dimensions
                // ==========================================
                _buildSectionHeader('DIMENSIONS', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    _buildSliderRow(
                      colors: colors,
                      label: 'Font Size',
                      valueStr: '${typography.fontSize.round()} pt',
                      value: typography.fontSize,
                      min: 12.0,
                      max: 32.0,
                      divisions: 20,
                      onChanged: (val) {
                        notifier.setFontSize(val.roundToDouble());
                      },
                    ),
                    _buildDivider(colors),
                    _buildSliderRow(
                      colors: colors,
                      label: 'Line Height',
                      valueStr: '${typography.lineHeight.toStringAsFixed(1)}x',
                      value: typography.lineHeight,
                      min: 1.0,
                      max: 2.5,
                      divisions: 15,
                      onChanged: (val) {
                        notifier.setLineHeight(
                            double.parse(val.toStringAsFixed(1)));
                      },
                    ),
                    _buildDivider(colors),
                    _buildSliderRow(
                      colors: colors,
                      label: 'Letter Spacing',
                      valueStr:
                          '${typography.letterSpacing.toStringAsFixed(1)} px',
                      value: typography.letterSpacing,
                      min: -1.0,
                      max: 2.0,
                      divisions: 30,
                      onChanged: (val) {
                        notifier.setLetterSpacing(
                            double.parse(val.toStringAsFixed(1)));
                      },
                    ),
                    _buildDivider(colors),
                    _buildSliderRow(
                      colors: colors,
                      label: 'Paragraph Indent',
                      valueStr: '${typography.paragraphIndent.round()} px',
                      value: typography.paragraphIndent,
                      min: 0.0,
                      max: 40.0,
                      divisions: 20,
                      onChanged: (val) {
                        notifier.setParagraphIndent(val.roundToDouble());
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ==========================================
                // Group 3: Layout & Actions
                // ==========================================
                _buildSectionHeader('LAYOUT & ACTIONS', colors),
                _buildGroupCard(
                  colors: colors,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Paragraph Width',
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          CupertinoSlidingSegmentedControl<ParagraphWidth>(
                            groupValue: typography.paragraphWidth,
                            backgroundColor: colors.background,
                            thumbColor: colors.surface,
                            children: const {
                              ParagraphWidth.narrow: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Narrow',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              ParagraphWidth.medium: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Medium',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              ParagraphWidth.full: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Full',
                                    style: TextStyle(fontSize: 12)),
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
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppRadii.lg),
                        ),
                      ),
                      title: Center(
                        child: Text(
                          'Reset to Default',
                          style: AppTypography.bodyMedium.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onTap: () async {
                        await notifier.resetToDefault();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Restored default typography'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // ==========================================
                // Group 4: Live Markdown Preview at Bottom
                // ==========================================
                _buildSectionHeader('LIVE PREVIEW', colors),
                Container(
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
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Preview header bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.tagBackground.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppRadii.lg),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: colors.divider.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Markdown Live Preview',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Preview body content (generous natural height, no clipping)
                      Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.md + typography.paragraphIndent,
                          right: AppSpacing.md,
                          top: AppSpacing.md,
                          bottom: AppSpacing.lg,
                        ),
                        child: SelectableText.rich(
                          styledTextSpan,
                          style: TextStyle(
                            fontSize: typography.fontSize,
                            height: typography.lineHeight,
                            letterSpacing: typography.letterSpacing,
                          ),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textTertiary,
          letterSpacing: 0.8,
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: AppSpacing.md,
      color: colors.divider.withValues(alpha: 0.4),
    );
  }

  Widget _buildFontPickerRow({
    required BuildContext context,
    required AppColors colors,
    required String title,
    required String fontFamily,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fontFamily,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: colors.textTertiary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSliderRow({
    required AppColors colors,
    required String label,
    required String valueStr,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  valueStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.accent,
              inactiveTrackColor: colors.divider.withValues(alpha: 0.4),
              thumbColor: colors.accent,
              overlayColor: colors.accent.withValues(alpha: 0.15),
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
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
