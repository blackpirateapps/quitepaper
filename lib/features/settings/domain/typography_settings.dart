import 'package:flutter/foundation.dart';

/// Pre-configured options for editor paragraph width constraint.
enum ParagraphWidth {
  narrow(540),
  medium(720),
  full(double.infinity);

  const ParagraphWidth(this.maxWidth);
  final double maxWidth;

  String get label {
    switch (this) {
      case ParagraphWidth.narrow:
        return 'Narrow';
      case ParagraphWidth.medium:
        return 'Medium';
      case ParagraphWidth.full:
        return 'Full';
    }
  }
}

/// Immutable configuration model for typography preferences.
@immutable
class TypographySettings {
  const TypographySettings({
    this.headingFontFamily,
    this.bodyFontFamily,
    this.codeFontFamily = 'monospace',
    this.interfaceFontFamily,
    this.fontSize = 18.0,
    this.lineHeight = 1.6,
    this.letterSpacing = 0.0,
    this.paragraphWidth = ParagraphWidth.medium,
    this.paragraphIndent = 0.0,
    this.customFonts = const [],
  });

  /// Factory defaults
  static const defaultSettings = TypographySettings();

  final String? headingFontFamily;
  final String? bodyFontFamily;
  final String? codeFontFamily;
  final String? interfaceFontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final ParagraphWidth paragraphWidth;
  final double paragraphIndent;
  final List<String> customFonts;

  /// Effective font family used across general UI elements (notes list, sidebar, tags, dialogs, search).
  /// If [interfaceFontFamily] is unset or 'Match Editor Body', automatically defaults to [bodyFontFamily].
  String? get effectiveUiFontFamily =>
      (interfaceFontFamily == null || interfaceFontFamily == 'Match Editor Body')
          ? bodyFontFamily
          : interfaceFontFamily;

  /// Effective font family used for UI headers, titles, and section banners.
  /// If [interfaceFontFamily] is unset or 'Match Editor Body', defaults to [headingFontFamily] ?? [bodyFontFamily].
  String? get effectiveUiTitleFontFamily =>
      (interfaceFontFamily == null || interfaceFontFamily == 'Match Editor Body')
          ? (headingFontFamily ?? bodyFontFamily)
          : interfaceFontFamily;

  // Proportional scaled sizes based on body font size (18pt default)
  double get scaledTitleSize => (fontSize * (30.0 / 18.0)).roundToDouble();
  double get scaledHeading1Size => (fontSize * (26.0 / 18.0)).roundToDouble();
  double get scaledHeading2Size => (fontSize * (22.0 / 18.0)).roundToDouble();
  double get scaledHeading3Size => (fontSize * (19.0 / 18.0)).roundToDouble();
  double get scaledHeading4Size => fontSize;
  double get scaledHeading5Size => (fontSize * (17.0 / 18.0)).roundToDouble();
  double get scaledHeading6Size => (fontSize * (16.0 / 18.0)).roundToDouble();
  double get scaledCodeSize => (fontSize * (15.0 / 18.0)).roundToDouble();

  TypographySettings copyWith({
    String? headingFontFamily,
    bool clearHeadingFont = false,
    String? bodyFontFamily,
    bool clearBodyFont = false,
    String? codeFontFamily,
    bool clearCodeFont = false,
    String? interfaceFontFamily,
    bool clearInterfaceFont = false,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    ParagraphWidth? paragraphWidth,
    double? paragraphIndent,
    List<String>? customFonts,
  }) {
    return TypographySettings(
      headingFontFamily: clearHeadingFont
          ? null
          : (headingFontFamily ?? this.headingFontFamily),
      bodyFontFamily:
          clearBodyFont ? null : (bodyFontFamily ?? this.bodyFontFamily),
      codeFontFamily:
          clearCodeFont ? null : (codeFontFamily ?? this.codeFontFamily),
      interfaceFontFamily: clearInterfaceFont
          ? null
          : (interfaceFontFamily ?? this.interfaceFontFamily),
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphWidth: paragraphWidth ?? this.paragraphWidth,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      customFonts: customFonts ?? this.customFonts,
    );
  }

  Map<String, dynamic> toJson() => {
        if (headingFontFamily != null)
          'headingFontFamily': headingFontFamily,
        if (bodyFontFamily != null) 'bodyFontFamily': bodyFontFamily,
        if (codeFontFamily != null) 'codeFontFamily': codeFontFamily,
        if (interfaceFontFamily != null)
          'interfaceFontFamily': interfaceFontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'letterSpacing': letterSpacing,
        'paragraphWidth': paragraphWidth.name,
        'paragraphIndent': paragraphIndent,
        'customFonts': customFonts,
      };

  factory TypographySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultSettings;

    ParagraphWidth width;
    try {
      width = ParagraphWidth.values.byName(
        json['paragraphWidth'] as String? ?? 'medium',
      );
    } catch (_) {
      width = ParagraphWidth.medium;
    }

    final rawCustom = json['customFonts'];
    final customList = rawCustom is List
        ? rawCustom.map((e) => e.toString()).toList()
        : <String>[];

    return TypographySettings(
      headingFontFamily: json['headingFontFamily'] as String?,
      bodyFontFamily: json['bodyFontFamily'] as String?,
      codeFontFamily: json['codeFontFamily'] as String? ?? 'monospace',
      interfaceFontFamily: json['interfaceFontFamily'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      paragraphWidth: width,
      paragraphIndent:
          (json['paragraphIndent'] as num?)?.toDouble() ?? 0.0,
      customFonts: customList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographySettings &&
          runtimeType == other.runtimeType &&
          headingFontFamily == other.headingFontFamily &&
          bodyFontFamily == other.bodyFontFamily &&
          codeFontFamily == other.codeFontFamily &&
          interfaceFontFamily == other.interfaceFontFamily &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          letterSpacing == other.letterSpacing &&
          paragraphWidth == other.paragraphWidth &&
          paragraphIndent == other.paragraphIndent &&
          listEquals(customFonts, other.customFonts);

  @override
  int get hashCode =>
      headingFontFamily.hashCode ^
      bodyFontFamily.hashCode ^
      codeFontFamily.hashCode ^
      interfaceFontFamily.hashCode ^
      fontSize.hashCode ^
      lineHeight.hashCode ^
      letterSpacing.hashCode ^
      paragraphWidth.hashCode ^
      paragraphIndent.hashCode ^
      customFonts.hashCode;
}
