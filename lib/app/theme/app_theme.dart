import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/font_family_helper.dart';
import '../../features/settings/domain/typography_settings.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';
import 'theme_family.dart';

abstract final class AppTheme {
  /// Builds light [ThemeData] for the specified [family] and dynamic [typography] preferences.
  static ThemeData light({
    ThemeFamily family = ThemeFamily.classicPaper,
    TypographySettings? typography,
  }) {
    final colors = family == ThemeFamily.warmPaper
        ? AppColors.warmPaperLight
        : AppColors.classicLight;

    final resolvedBodyFont =
        FontFamilyHelper.resolveBodyFontFamily(typography?.effectiveUiFontFamily);
    final resolvedTitleFont =
        FontFamilyHelper.resolveHeadingFontFamily(typography?.effectiveUiTitleFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: resolvedBodyFont,
      textTheme: AppTypography.createTextTheme(typography),
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.light(
        primary: colors.accent,
        onPrimary: Colors.white,
        primaryContainer: colors.accentSoft,
        onPrimaryContainer: colors.accentDark,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.tagBackground,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.divider,
        outlineVariant: colors.borderSubtle,
        error: colors.error,
        onError: Colors.white,
      ),
      extensions: [
        colors,
        AppTypography.fromTypographySettings(typography),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedTitleFont,
          baseStyle: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textSecondary, size: 22),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.selection,
        selectionHandleColor: colors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.body.copyWith(color: colors.textTertiary),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        titleTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedTitleFont,
          baseStyle: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        contentTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        elevation: 8,
        modalElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
        ),
        showDragHandle: true,
        dragHandleColor: colors.textTertiary.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.bodySmall.copyWith(color: colors.background),
        ),
        actionTextColor: colors.accent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderBtn),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        textStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.bodySmallMedium.copyWith(color: colors.textPrimary),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary.withValues(alpha: 0.9),
          borderRadius: AppRadii.borderSm,
        ),
        textStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.caption.copyWith(color: colors.background),
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
        triggerMode: TooltipTriggerMode.longPress,
      ),
    );
  }

  /// Builds dark [ThemeData] for the specified [family] and dynamic [typography] preferences.
  static ThemeData dark({
    ThemeFamily family = ThemeFamily.classicPaper,
    TypographySettings? typography,
  }) {
    final colors = family == ThemeFamily.warmPaper
        ? AppColors.midnightPaperDark
        : AppColors.classicDark;

    final resolvedBodyFont =
        FontFamilyHelper.resolveBodyFontFamily(typography?.effectiveUiFontFamily);
    final resolvedTitleFont =
        FontFamilyHelper.resolveHeadingFontFamily(typography?.effectiveUiTitleFontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: resolvedBodyFont,
      textTheme: AppTypography.createTextTheme(typography),
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.accent,
        onPrimary: colors.background,
        primaryContainer: colors.accentSoft,
        onPrimaryContainer: colors.accent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.tagBackground,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.divider,
        outlineVariant: colors.borderSubtle,
        error: colors.error,
        onError: Colors.white,
      ),
      extensions: [
        colors,
        AppTypography.fromTypographySettings(typography),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedTitleFont,
          baseStyle: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textSecondary, size: 22),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.selection,
        selectionHandleColor: colors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.body.copyWith(color: colors.textTertiary),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        titleTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedTitleFont,
          baseStyle: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        contentTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        elevation: 8,
        modalElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
        ),
        showDragHandle: true,
        dragHandleColor: colors.textTertiary.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.elevated,
        contentTextStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        ),
        actionTextColor: colors.accent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderBtn),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        textStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.bodySmallMedium.copyWith(color: colors.textPrimary),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary.withValues(alpha: 0.9),
          borderRadius: AppRadii.borderSm,
        ),
        textStyle: FontFamilyHelper.getTextStyle(
          fontFamily: resolvedBodyFont,
          baseStyle: AppTypography.caption.copyWith(color: colors.background),
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
        triggerMode: TooltipTriggerMode.longPress,
      ),
    );
  }

  // Canonical Theme Factories
  static ThemeData classicLight({TypographySettings? typography}) =>
      light(family: ThemeFamily.classicPaper, typography: typography);
  static ThemeData classicDark({TypographySettings? typography}) =>
      dark(family: ThemeFamily.classicPaper, typography: typography);
  static ThemeData warmPaperLight({TypographySettings? typography}) =>
      light(family: ThemeFamily.warmPaper, typography: typography);
  static ThemeData midnightPaperDark({TypographySettings? typography}) =>
      dark(family: ThemeFamily.warmPaper, typography: typography);
}
