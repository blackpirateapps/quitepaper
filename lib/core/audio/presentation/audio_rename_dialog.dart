import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/font_family_helper.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../widgets/quiet_button.dart';

/// Minimal editorial dialog for renaming an audio journal recording.
class AudioRenameDialog extends ConsumerStatefulWidget {
  const AudioRenameDialog({
    super.key,
    required this.currentTitle,
  });

  final String currentTitle;

  static Future<String?> show(BuildContext context, {required String currentTitle}) {
    return showDialog<String>(
      context: context,
      builder: (context) => AudioRenameDialog(currentTitle: currentTitle),
    );
  }

  @override
  ConsumerState<AudioRenameDialog> createState() => _AudioRenameDialogState();
}

class _AudioRenameDialogState extends ConsumerState<AudioRenameDialog> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentTitle.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final headingFont = FontFamilyHelper.resolveHeadingFontFamily(
      typography.headingFontFamily ?? typography.bodyFontFamily,
    );
    final bodyFont = FontFamilyHelper.resolveBodyFontFamily(
      typography.bodyFontFamily,
    );

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderMd,
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      elevation: 3,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rename Voice Memo',
                style: FontFamilyHelper.getTextStyle(
                  fontFamily: headingFont,
                  baseStyle: TextStyle(
                    color: colors.textPrimary,
                    fontSize: typography.scaleFontSize(20.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: typography.letterSpacing,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: FontFamilyHelper.getTextStyle(
                  fontFamily: bodyFont,
                  baseStyle: TextStyle(
                    color: colors.textPrimary,
                    fontSize: typography.scaleFontSize(16.0),
                    letterSpacing: typography.letterSpacing,
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter title…',
                  hintStyle: FontFamilyHelper.getTextStyle(
                    fontFamily: bodyFont,
                    baseStyle: TextStyle(
                      color: colors.textTertiary,
                      fontSize: typography.scaleFontSize(16.0),
                      letterSpacing: typography.letterSpacing,
                    ),
                  ),
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderSm,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderSm,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderSm,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  QuietButton(
                    label: 'Cancel',
                    variant: QuietButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  QuietButton(
                    label: 'Save',
                    variant: QuietButtonVariant.primary,
                    onPressed: _submit,
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
