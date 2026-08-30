import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/syntax/application/syntax_language_registry.dart';

/// An interactive, editorial pill displayed at the top-right of a code block in the Markdown editor.
/// Tapping opens the searchable [LanguageSelectorSheet] to change or assign a language.
class CodeBlockLanguagePill extends StatelessWidget {
  const CodeBlockLanguagePill({
    super.key,
    required this.language,
    required this.onTap,
    this.enabled = true,
  });

  final String language;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final trimmedLang = language.trim();

    final hasLanguage = trimmedLang.isNotEmpty;
    final registered = hasLanguage
        ? SyntaxLanguageRegistry.instance.findByIdOrAlias(trimmedLang)
        : null;
    final displayName = registered?.name ?? (hasLanguage ? trimmedLang : 'Plain text');

    final textColor = hasLanguage ? colors.accent : colors.textTertiary;

    return Tooltip(
      message: 'Select code block language',
      child: Material(
        color: colors.surface.withValues(alpha: 0.94),
        elevation: 0,
        borderRadius: AppRadii.borderSm,
        child: InkWell(
          borderRadius: AppRadii.borderSm,
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              borderRadius: AppRadii.borderSm,
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.8),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  displayName,
                  style: AppTypography.caption.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: 3.0),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14.0,
                  color: textColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
