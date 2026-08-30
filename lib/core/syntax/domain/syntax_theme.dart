import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/font_family_helper.dart';
import '../../../features/settings/domain/typography_settings.dart';
import 'syntax_token_type.dart';

/// Centralized, theme-aware syntax theme mapping semantic [SyntaxTokenType]s to [TextStyle]s.
/// Adheres strictly to Quiet Paper's calm, editorial, non-noisy aesthetic.
@immutable
class SyntaxTheme {
  const SyntaxTheme({
    required this.plain,
    required this.keyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.function,
    required this.method,
    required this.type,
    required this.className,
    required this.variable,
    required this.constant,
    required this.operator,
    required this.punctuation,
    required this.property,
    required this.attribute,
    required this.tag,
    required this.builtin,
    required this.literal,
    required this.regexp,
    required this.annotation,
    required this.meta,
    required this.heading,
    required this.link,
  });

  final TextStyle plain;
  final TextStyle keyword;
  final TextStyle string;
  final TextStyle number;
  final TextStyle comment;
  final TextStyle function;
  final TextStyle method;
  final TextStyle type;
  final TextStyle className;
  final TextStyle variable;
  final TextStyle constant;
  final TextStyle operator;
  final TextStyle punctuation;
  final TextStyle property;
  final TextStyle attribute;
  final TextStyle tag;
  final TextStyle builtin;
  final TextStyle literal;
  final TextStyle regexp;
  final TextStyle annotation;
  final TextStyle meta;
  final TextStyle heading;
  final TextStyle link;

  /// Returns the corresponding [TextStyle] for a given [SyntaxTokenType].
  TextStyle styleFor(SyntaxTokenType tokenType) {
    switch (tokenType) {
      case SyntaxTokenType.plain:
        return plain;
      case SyntaxTokenType.keyword:
        return keyword;
      case SyntaxTokenType.string:
        return string;
      case SyntaxTokenType.number:
        return number;
      case SyntaxTokenType.comment:
        return comment;
      case SyntaxTokenType.function:
        return function;
      case SyntaxTokenType.method:
        return method;
      case SyntaxTokenType.type:
        return type;
      case SyntaxTokenType.className:
        return className;
      case SyntaxTokenType.variable:
        return variable;
      case SyntaxTokenType.constant:
        return constant;
      case SyntaxTokenType.operator:
        return operator;
      case SyntaxTokenType.punctuation:
        return punctuation;
      case SyntaxTokenType.property:
        return property;
      case SyntaxTokenType.attribute:
        return attribute;
      case SyntaxTokenType.tag:
        return tag;
      case SyntaxTokenType.builtin:
        return builtin;
      case SyntaxTokenType.literal:
        return literal;
      case SyntaxTokenType.regexp:
        return regexp;
      case SyntaxTokenType.annotation:
        return annotation;
      case SyntaxTokenType.meta:
        return meta;
      case SyntaxTokenType.heading:
        return heading;
      case SyntaxTokenType.link:
        return link;
    }
  }

  /// Factory constructor to derive a syntax theme dynamically from [AppColors]
  /// and optional [TypographySettings].
  factory SyntaxTheme.fromColors(
    AppColors colors, {
    TypographySettings? typography,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
  }) {
    final typo = typography ?? TypographySettings.defaultSettings;
    final isDark = colors.background.computeLuminance() < 0.5;

    final codeFont = fontFamily ?? typo.codeFontFamily ?? 'monospace';
    final effectiveSize = fontSize ?? typo.scaledCodeSize;
    final effectiveHeight = lineHeight ?? typo.lineHeight;
    final effectiveSpacing = letterSpacing ?? typo.letterSpacing;

    TextStyle base({
      required Color color,
      FontWeight weight = FontWeight.w400,
      FontStyle style = FontStyle.normal,
      TextDecoration decoration = TextDecoration.none,
    }) {
      return FontFamilyHelper.getTextStyle(
        fontFamily: codeFont,
        baseStyle: TextStyle(
          fontSize: effectiveSize,
          height: effectiveHeight,
          letterSpacing: effectiveSpacing,
          color: color,
          fontWeight: weight,
          fontStyle: style,
          decoration: decoration,
        ),
      );
    }

    // Curated, editorial color tokens (calm & legible across both light and dark modes)
    final plainColor = colors.textPrimary;
    final keywordColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9); // Soft Purple
    final stringColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D); // Sage/Forest Green
    final numberColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309); // Amber Ochre
    final commentColor = colors.textTertiary.withValues(alpha: isDark ? 0.75 : 0.85); // Muted Slate
    final functionColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8); // Soft Blue
    final typeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1); // Sky/Teal
    final variableColor = colors.textPrimary;
    final constantColor = isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D); // Rose
    final operatorColor = colors.textSecondary;
    final punctuationColor = colors.textTertiary;
    final propertyColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E); // Teal
    final tagColor = colors.accent;
    final builtinColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE); // Violet
    final literalColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C); // Warm Orange
    final regexpColor = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C); // Coral Red
    final annotationColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569); // Slate

    return SyntaxTheme(
      plain: base(color: plainColor),
      keyword: base(color: keywordColor, weight: FontWeight.w600),
      string: base(color: stringColor),
      number: base(color: numberColor),
      comment: base(color: commentColor, style: FontStyle.italic),
      function: base(color: functionColor, weight: FontWeight.w500),
      method: base(color: functionColor, weight: FontWeight.w500),
      type: base(color: typeColor, weight: FontWeight.w600),
      className: base(color: typeColor, weight: FontWeight.w600),
      variable: base(color: variableColor),
      constant: base(color: constantColor, weight: FontWeight.w500),
      operator: base(color: operatorColor),
      punctuation: base(color: punctuationColor),
      property: base(color: propertyColor),
      attribute: base(color: propertyColor),
      tag: base(color: tagColor, weight: FontWeight.w600),
      builtin: base(color: builtinColor, weight: FontWeight.w500),
      literal: base(color: literalColor, weight: FontWeight.w500),
      regexp: base(color: regexpColor),
      annotation: base(color: annotationColor, style: FontStyle.italic),
      meta: base(color: annotationColor),
      heading: base(color: keywordColor, weight: FontWeight.bold),
      link: base(color: tagColor, decoration: TextDecoration.underline),
    );
  }
}
