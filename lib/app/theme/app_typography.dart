import 'package:flutter/material.dart';
import '../../core/utils/font_family_helper.dart';
import '../../features/settings/domain/typography_settings.dart';

abstract final class AppTypography {
  // Base font family - system default
  static const String? fontFamily = null;

  // General UI Typography
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 38 / 32,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 30 / 24,
    letterSpacing: -0.3,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 26 / 20,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 25 / 16,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 25 / 16,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle bodySmallMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 17 / 12,
    letterSpacing: 0.2,
  );

  // Editor Typography
  static const TextStyle editorTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 36 / 30,
    letterSpacing: -0.5,
  );

  static const TextStyle editorH1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 33 / 26,
    letterSpacing: -0.3,
  );

  static const TextStyle editorH2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 29 / 22,
    letterSpacing: -0.2,
  );

  static const TextStyle editorH3 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 26 / 19,
  );

  static const TextStyle editorBody = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 29 / 18,
  );

  static const TextStyle editorQuote = TextStyle(
    fontSize: 18,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    height: 29 / 18,
  );

  static const TextStyle editorCode = TextStyle(
    fontSize: 15,
    fontFamily: 'monospace',
    fontWeight: FontWeight.w400,
    height: 23 / 15,
  );

  // Tag styling
  static const TextStyle tag = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0.1,
  );

  /// Constructs a complete Material [TextTheme] bound to the active [typography] settings.
  static TextTheme createTextTheme(TypographySettings? typography) {
    final titleFamily = FontFamilyHelper.resolveHeadingFontFamily(typography?.effectiveUiTitleFontFamily);
    final bodyFamily = FontFamilyHelper.resolveBodyFontFamily(typography?.effectiveUiFontFamily);

    TextStyle withTitle(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: titleFamily, baseStyle: base);

    TextStyle withBody(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: bodyFamily, baseStyle: base);

    return TextTheme(
      displayLarge: withTitle(display),
      displayMedium: withTitle(display.copyWith(fontSize: 28)),
      displaySmall: withTitle(display.copyWith(fontSize: 24)),
      headlineLarge: withTitle(title),
      headlineMedium: withTitle(headline),
      headlineSmall: withTitle(headline.copyWith(fontSize: 18)),
      titleLarge: withTitle(title),
      titleMedium: withTitle(headline),
      titleSmall: withTitle(headline.copyWith(fontSize: 15)),
      bodyLarge: withBody(bodyLarge),
      bodyMedium: withBody(body),
      bodySmall: withBody(bodySmall),
      labelLarge: withBody(bodyMedium),
      labelMedium: withBody(bodySmallMedium),
      labelSmall: withBody(caption),
    );
  }

  /// Builds an [AppTypographyTheme] extension populated with dynamically resolved font families.
  static AppTypographyTheme fromTypographySettings(TypographySettings? typography) {
    final titleFamily = FontFamilyHelper.resolveHeadingFontFamily(typography?.effectiveUiTitleFontFamily);
    final bodyFamily = FontFamilyHelper.resolveBodyFontFamily(typography?.effectiveUiFontFamily);
    final headingEditorFamily = FontFamilyHelper.resolveHeadingFontFamily(typography?.headingFontFamily);
    final bodyEditorFamily = FontFamilyHelper.resolveBodyFontFamily(typography?.bodyFontFamily);
    final codeFamily = typography?.codeFontFamily;

    TextStyle withTitle(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: titleFamily, baseStyle: base);

    TextStyle withBody(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: bodyFamily, baseStyle: base);

    TextStyle withHeadingEditor(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: headingEditorFamily, baseStyle: base);

    TextStyle withBodyEditor(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: bodyEditorFamily, baseStyle: base);

    TextStyle withCode(TextStyle base) =>
        FontFamilyHelper.getTextStyle(fontFamily: codeFamily, baseStyle: base);

    final fontSize = typography?.fontSize ?? 18.0;
    final lineHeight = typography?.lineHeight ?? 1.6;
    final letterSpacing = typography?.letterSpacing ?? 0.0;

    return AppTypographyTheme(
      display: withTitle(display),
      title: withTitle(title),
      headline: withTitle(headline),
      bodyLarge: withBody(bodyLarge),
      body: withBody(body),
      bodyMedium: withBody(bodyMedium),
      bodySmall: withBody(bodySmall),
      bodySmallMedium: withBody(bodySmallMedium),
      caption: withBody(caption),
      tag: withBody(tag),
      editorTitle: withHeadingEditor(editorTitle.copyWith(
        fontSize: typography?.scaledTitleSize ?? 30.0,
        height: (36.0 / 30.0) * (lineHeight / 1.6),
        letterSpacing: letterSpacing,
      )),
      editorH1: withHeadingEditor(editorH1.copyWith(
        fontSize: typography?.scaledHeading1Size ?? 26.0,
        height: (33.0 / 26.0) * (lineHeight / 1.6),
        letterSpacing: letterSpacing,
      )),
      editorH2: withHeadingEditor(editorH2.copyWith(
        fontSize: typography?.scaledHeading2Size ?? 22.0,
        height: (29.0 / 22.0) * (lineHeight / 1.6),
        letterSpacing: letterSpacing,
      )),
      editorH3: withHeadingEditor(editorH3.copyWith(
        fontSize: typography?.scaledHeading3Size ?? 19.0,
        height: (26.0 / 19.0) * (lineHeight / 1.6),
        letterSpacing: letterSpacing,
      )),
      editorBody: withBodyEditor(editorBody.copyWith(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
      )),
      editorQuote: withBodyEditor(editorQuote.copyWith(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
      )),
      editorCode: withCode(editorCode.copyWith(
        fontSize: typography?.scaledCodeSize ?? 15.0,
        letterSpacing: letterSpacing,
      )),
    );
  }
}

/// ThemeExtension holding dynamically resolved typography styles.
@immutable
class AppTypographyTheme extends ThemeExtension<AppTypographyTheme> {
  const AppTypographyTheme({
    required this.display,
    required this.title,
    required this.headline,
    required this.bodyLarge,
    required this.body,
    required this.bodyMedium,
    required this.bodySmall,
    required this.bodySmallMedium,
    required this.caption,
    required this.tag,
    required this.editorTitle,
    required this.editorH1,
    required this.editorH2,
    required this.editorH3,
    required this.editorBody,
    required this.editorQuote,
    required this.editorCode,
  });

  final TextStyle display;
  final TextStyle title;
  final TextStyle headline;
  final TextStyle bodyLarge;
  final TextStyle body;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle bodySmallMedium;
  final TextStyle caption;
  final TextStyle tag;
  final TextStyle editorTitle;
  final TextStyle editorH1;
  final TextStyle editorH2;
  final TextStyle editorH3;
  final TextStyle editorBody;
  final TextStyle editorQuote;
  final TextStyle editorCode;

  static const fallback = AppTypographyTheme(
    display: AppTypography.display,
    title: AppTypography.title,
    headline: AppTypography.headline,
    bodyLarge: AppTypography.bodyLarge,
    body: AppTypography.body,
    bodyMedium: AppTypography.bodyMedium,
    bodySmall: AppTypography.bodySmall,
    bodySmallMedium: AppTypography.bodySmallMedium,
    caption: AppTypography.caption,
    tag: AppTypography.tag,
    editorTitle: AppTypography.editorTitle,
    editorH1: AppTypography.editorH1,
    editorH2: AppTypography.editorH2,
    editorH3: AppTypography.editorH3,
    editorBody: AppTypography.editorBody,
    editorQuote: AppTypography.editorQuote,
    editorCode: AppTypography.editorCode,
  );

  @override
  ThemeExtension<AppTypographyTheme> copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? headline,
    TextStyle? bodyLarge,
    TextStyle? body,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? bodySmallMedium,
    TextStyle? caption,
    TextStyle? tag,
    TextStyle? editorTitle,
    TextStyle? editorH1,
    TextStyle? editorH2,
    TextStyle? editorH3,
    TextStyle? editorBody,
    TextStyle? editorQuote,
    TextStyle? editorCode,
  }) {
    return AppTypographyTheme(
      display: display ?? this.display,
      title: title ?? this.title,
      headline: headline ?? this.headline,
      bodyLarge: bodyLarge ?? this.bodyLarge,
      body: body ?? this.body,
      bodyMedium: bodyMedium ?? this.bodyMedium,
      bodySmall: bodySmall ?? this.bodySmall,
      bodySmallMedium: bodySmallMedium ?? this.bodySmallMedium,
      caption: caption ?? this.caption,
      tag: tag ?? this.tag,
      editorTitle: editorTitle ?? this.editorTitle,
      editorH1: editorH1 ?? this.editorH1,
      editorH2: editorH2 ?? this.editorH2,
      editorH3: editorH3 ?? this.editorH3,
      editorBody: editorBody ?? this.editorBody,
      editorQuote: editorQuote ?? this.editorQuote,
      editorCode: editorCode ?? this.editorCode,
    );
  }

  @override
  ThemeExtension<AppTypographyTheme> lerp(
    covariant ThemeExtension<AppTypographyTheme>? other,
    double t,
  ) {
    if (other is! AppTypographyTheme) return this;
    return AppTypographyTheme(
      display: TextStyle.lerp(display, other.display, t) ?? display,
      title: TextStyle.lerp(title, other.title, t) ?? title,
      headline: TextStyle.lerp(headline, other.headline, t) ?? headline,
      bodyLarge: TextStyle.lerp(bodyLarge, other.bodyLarge, t) ?? bodyLarge,
      body: TextStyle.lerp(body, other.body, t) ?? body,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t) ?? bodyMedium,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t) ?? bodySmall,
      bodySmallMedium: TextStyle.lerp(bodySmallMedium, other.bodySmallMedium, t) ?? bodySmallMedium,
      caption: TextStyle.lerp(caption, other.caption, t) ?? caption,
      tag: TextStyle.lerp(tag, other.tag, t) ?? tag,
      editorTitle: TextStyle.lerp(editorTitle, other.editorTitle, t) ?? editorTitle,
      editorH1: TextStyle.lerp(editorH1, other.editorH1, t) ?? editorH1,
      editorH2: TextStyle.lerp(editorH2, other.editorH2, t) ?? editorH2,
      editorH3: TextStyle.lerp(editorH3, other.editorH3, t) ?? editorH3,
      editorBody: TextStyle.lerp(editorBody, other.editorBody, t) ?? editorBody,
      editorQuote: TextStyle.lerp(editorQuote, other.editorQuote, t) ?? editorQuote,
      editorCode: TextStyle.lerp(editorCode, other.editorCode, t) ?? editorCode,
    );
  }
}

extension AppTypographyContext on BuildContext {
  AppTypographyTheme get appTypography =>
      Theme.of(this).extension<AppTypographyTheme>() ?? AppTypographyTheme.fallback;
}
