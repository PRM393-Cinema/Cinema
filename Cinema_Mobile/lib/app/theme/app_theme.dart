import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final colors = AppPalette(isLight: brightness == Brightness.light);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: colors.isLight ? Colors.white : colors.background,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.border,
      outlineVariant: colors.border,
      surfaceContainerHighest: colors.surfaceSoft,
      error: colors.error,
      onError: colors.isLight ? Colors.white : colors.background,
    );

    return ThemeData(
      useMaterial3: true,
      extensions: [colors],
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      hoverColor: colors.isLight
          ? colors.primary.withValues(alpha: 0.05)
          : null,
      focusColor: colors.isLight
          ? colors.primary.withValues(alpha: 0.12)
          : null,
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.heading1,
        headlineMedium: AppTextStyles.heading2,
        titleLarge: AppTextStyles.title,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySmall,
        labelSmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.button,
      ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.title.copyWith(color: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.isLight ? colors.surface : colors.surfaceSoft,
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMd,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMd,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMd,
          borderSide: BorderSide(
            color: colors.primary,
            width: colors.isLight ? 2 : 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderRadiusMd,
          borderSide: BorderSide(color: colors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceSoft,
          disabledForegroundColor: colors.textSecondary,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: colors.isLight
              ? AppRadius.borderRadiusMd
              : AppRadius.borderRadiusLg,
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerColor: colors.border,
    );
  }
}
