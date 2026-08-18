import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

class QuietMarkdownPreview extends StatelessWidget {
  const QuietMarkdownPreview({
    super.key,
    required this.markdownData,
    this.selectable = true,
  });

  final String markdownData;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final customStyleSheet = MarkdownStyleSheet(
      h1: AppTypography.editorH1.copyWith(color: colors.textPrimary),
      h2: AppTypography.editorH2.copyWith(color: colors.textPrimary),
      h3: AppTypography.editorH3.copyWith(color: colors.textPrimary),
      p: AppTypography.editorBody.copyWith(color: colors.textPrimary),
      pPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      blockquote: AppTypography.editorQuote.copyWith(
        color: colors.textSecondary,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(color: colors.accent, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: AppRadii.rSm,
          bottomRight: AppRadii.rSm,
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
      code: AppTypography.editorCode.copyWith(
        color: colors.accentDark,
        backgroundColor: colors.tagBackground,
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      listBullet: AppTypography.editorBody.copyWith(color: colors.accent),
      listBulletPadding: const EdgeInsets.only(right: AppSpacing.sm),
      a: AppTypography.editorBody.copyWith(
        color: colors.accent,
        decoration: TextDecoration.underline,
        decorationColor: colors.accent.withValues(alpha: 0.5),
      ),
      tableHead: AppTypography.bodySmallMedium.copyWith(color: colors.textPrimary),
      tableBody: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
      tableBorder: TableBorder.all(color: colors.divider, width: 1),
      tableHeadAlign: TextAlign.left,
      tablePadding: const EdgeInsets.all(AppSpacing.sm),
    );

    return MarkdownBody(
      data: markdownData.trim().isEmpty ? '*No content*' : markdownData,
      selectable: selectable,
      styleSheet: customStyleSheet,
    );
  }
}
