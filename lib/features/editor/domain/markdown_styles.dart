import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

/// Centralized Markdown styling definition for the WYSIWYG editor.
/// Adapts seamlessly to the active application theme (Light and Dark).
@immutable
class MarkdownStyles {
  const MarkdownStyles({
    required this.heading1,
    required this.heading2,
    required this.heading3,
    required this.heading4,
    required this.heading5,
    required this.heading6,
    required this.headingMarker,
    required this.body,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.strikethrough,
    required this.highlight,
    required this.inlineCode,
    required this.inlineCodeMarker,
    required this.codeBlock,
    required this.codeBlockFence,
    required this.blockquote,
    required this.blockquoteMarker,
    required this.listMarker,
    required this.checklistMarker,
    required this.checklistMarkerChecked,
    required this.taskTextCompleted,
    required this.link,
    required this.linkUrl,
    required this.tag,
    required this.syntaxMarker,
    required this.horizontalRule,
    required this.frontmatter,
    required this.frontmatterDelimiter,
  });

  final TextStyle heading1;
  final TextStyle heading2;
  final TextStyle heading3;
  final TextStyle heading4;
  final TextStyle heading5;
  final TextStyle heading6;
  final TextStyle headingMarker;
  final TextStyle body;
  final TextStyle bold;
  final TextStyle italic;
  final TextStyle boldItalic;
  final TextStyle strikethrough;
  final TextStyle highlight;
  final TextStyle inlineCode;
  final TextStyle inlineCodeMarker;
  final TextStyle codeBlock;
  final TextStyle codeBlockFence;
  final TextStyle blockquote;
  final TextStyle blockquoteMarker;
  final TextStyle listMarker;
  final TextStyle checklistMarker;
  final TextStyle checklistMarkerChecked;
  final TextStyle taskTextCompleted;
  final TextStyle link;
  final TextStyle linkUrl;
  final TextStyle tag;
  final TextStyle syntaxMarker;
  final TextStyle horizontalRule;
  final TextStyle frontmatter;
  final TextStyle frontmatterDelimiter;

  /// Factory constructor to derive Markdown styles from [AppColors] and an optional [baseStyle].
  factory MarkdownStyles.fromColors(
    AppColors colors, {
    TextStyle? baseStyle,
  }) {
    final effectiveBody = (baseStyle ?? AppTypography.editorBody).copyWith(
      color: colors.textPrimary,
    );

    return MarkdownStyles(
      heading1: AppTypography.editorH1.copyWith(
        color: colors.textPrimary,
      ),
      heading2: AppTypography.editorH2.copyWith(
        color: colors.textPrimary,
      ),
      heading3: AppTypography.editorH3.copyWith(
        color: colors.textPrimary,
      ),
      heading4: effectiveBody.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      heading5: effectiveBody.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      heading6: effectiveBody.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      headingMarker: TextStyle(
        color: colors.textTertiary.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500,
      ),
      body: effectiveBody,
      bold: const TextStyle(
        fontWeight: FontWeight.w700,
      ),
      italic: const TextStyle(
        fontStyle: FontStyle.italic,
      ),
      boldItalic: const TextStyle(
        fontWeight: FontWeight.w700,
        fontStyle: FontStyle.italic,
      ),
      strikethrough: const TextStyle(
        decoration: TextDecoration.lineThrough,
      ),
      highlight: TextStyle(
        backgroundColor: colors.accent.withValues(alpha: 0.22),
        fontWeight: FontWeight.w500,
      ),
      inlineCode: AppTypography.editorCode.copyWith(
        color: colors.accentDark,
        backgroundColor: colors.tagBackground.withValues(alpha: 0.5),
      ),
      inlineCodeMarker: AppTypography.editorCode.copyWith(
        color: colors.textTertiary.withValues(alpha: 0.6),
      ),
      codeBlock: AppTypography.editorCode.copyWith(
        color: colors.textPrimary,
      ),
      codeBlockFence: AppTypography.editorCode.copyWith(
        color: colors.textTertiary.withValues(alpha: 0.7),
      ),
      blockquote: AppTypography.editorQuote.copyWith(
        color: colors.textSecondary,
      ),
      blockquoteMarker: TextStyle(
        color: colors.accent.withValues(alpha: 0.7),
        fontWeight: FontWeight.w700,
      ),
      listMarker: TextStyle(
        color: colors.accent,
        fontWeight: FontWeight.w600,
      ),
      checklistMarker: TextStyle(
        color: colors.accent,
        fontWeight: FontWeight.w600,
      ),
      checklistMarkerChecked: TextStyle(
        color: colors.textTertiary.withValues(alpha: 0.8),
        fontWeight: FontWeight.w600,
      ),
      taskTextCompleted: effectiveBody.copyWith(
        color: colors.textSecondary.withValues(alpha: 0.7),
        decoration: TextDecoration.lineThrough,
        decorationColor: colors.textTertiary,
      ),
      link: TextStyle(
        color: colors.accent,
        decoration: TextDecoration.underline,
        decorationColor: colors.accent.withValues(alpha: 0.5),
      ),
      linkUrl: TextStyle(
        color: colors.textTertiary.withValues(alpha: 0.7),
      ),
      tag: AppTypography.tag.copyWith(
        color: colors.accent,
        fontWeight: FontWeight.w600,
      ),
      syntaxMarker: TextStyle(
        color: colors.textTertiary.withValues(alpha: 0.6),
      ),
      horizontalRule: TextStyle(
        color: colors.textTertiary.withValues(alpha: 0.5),
        letterSpacing: 4.0,
        fontWeight: FontWeight.bold,
      ),
      frontmatter: AppTypography.editorCode.copyWith(
        color: colors.textSecondary.withValues(alpha: 0.8),
      ),
      frontmatterDelimiter: AppTypography.editorCode.copyWith(
        color: colors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }

  /// Get the corresponding heading style for level 1 to 6.
  TextStyle getHeadingStyle(int level) {
    switch (level) {
      case 1:
        return heading1;
      case 2:
        return heading2;
      case 3:
        return heading3;
      case 4:
        return heading4;
      case 5:
        return heading5;
      case 6:
        return heading6;
      default:
        return heading1;
    }
  }
}
