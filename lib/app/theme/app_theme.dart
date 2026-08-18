import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const colors = AppColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
        outlineVariant: colors.divider,
        error: colors.error,
        onError: Colors.white,
      ),
      extensions: const [colors],
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
        titleTextStyle: AppTypography.title.copyWith(color: colors.textPrimary),
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
        hintStyle: AppTypography.body.copyWith(color: colors.textTertiary),
        contentPadding: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        titleTextStyle: AppTypography.headline.copyWith(color: colors.textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: colors.textSecondary),
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
        contentTextStyle: AppTypography.bodySmall.copyWith(color: colors.background),
        actionTextColor: colors.accent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderBtn),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        textStyle: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary.withValues(alpha: 0.9),
          borderRadius: AppRadii.borderSm,
        ),
        textStyle: AppTypography.caption.copyWith(color: colors.background),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
        triggerMode: TooltipTriggerMode.longPress,
      ),
    );
  }

  static ThemeData dark() {
    const colors = AppColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.accent,
        onPrimary: const Color(0xFF1D1C1A),
        primaryContainer: colors.accentSoft,
        onPrimaryContainer: colors.accent,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.tagBackground,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.divider,
        outlineVariant: colors.divider,
        error: colors.error,
        onError: Colors.white,
      ),
      extensions: const [colors],
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
        titleTextStyle: AppTypography.title.copyWith(color: colors.textPrimary),
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
        hintStyle: AppTypography.body.copyWith(color: colors.textTertiary),
        contentPadding: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        titleTextStyle: AppTypography.headline.copyWith(color: colors.textPrimary),
        contentTextStyle: AppTypography.body.copyWith(color: colors.textSecondary),
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
        contentTextStyle: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
        actionTextColor: colors.accent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderBtn),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: 4,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
        textStyle: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary.withValues(alpha: 0.9),
          borderRadius: AppRadii.borderSm,
        ),
        textStyle: AppTypography.caption.copyWith(color: colors.background),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
        triggerMode: TooltipTriggerMode.longPress,
      ),
    );
  }
}
