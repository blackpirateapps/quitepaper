import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../widgets/quiet_button.dart';
import '../ocr_models.dart';
import '../ocr_provider.dart';

/// Modal dialog allowing the user to view and configure their preferred OCR recognition language.
class OcrLanguageDialog extends ConsumerStatefulWidget {
  const OcrLanguageDialog({
    super.key,
    this.initialLanguage,
  });

  final OcrLanguage? initialLanguage;

  static Future<OcrLanguage?> show(
    BuildContext context, {
    OcrLanguage? initialLanguage,
  }) {
    return showDialog<OcrLanguage>(
      context: context,
      builder: (_) => OcrLanguageDialog(initialLanguage: initialLanguage),
    );
  }

  @override
  ConsumerState<OcrLanguageDialog> createState() => _OcrLanguageDialogState();
}

class _OcrLanguageDialogState extends ConsumerState<OcrLanguageDialog> {
  late OcrLanguage _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage ??
        ref.read(ocrLanguagePreferenceProvider);
  }

  Future<void> _handleSave() async {
    await ref.read(ocrLanguagePreferenceProvider.notifier).setLanguage(_selectedLanguage);
    if (mounted) {
      Navigator.of(context).pop(_selectedLanguage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OCR Language',
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select on-device text recognition language',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.sm),

              // Language options (Only supported languages)
              ...OcrLanguage.values.map((lang) {
                final isSelected = _selectedLanguage == lang;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedLanguage = lang;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accent.withValues(alpha: 0.08)
                          : colors.background,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: isSelected ? colors.accent : colors.divider,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 20,
                          color: isSelected ? colors.accent : colors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            lang.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.sm / 2),
                            border: Border.all(color: colors.divider, width: 0.6),
                          ),
                          child: Text(
                            lang.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.lg),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  QuietButton(
                    label: 'Cancel',
                    variant: QuietButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  QuietButton(
                    label: 'Save',
                    variant: QuietButtonVariant.primary,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
