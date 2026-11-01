import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF0B0D12);
  static const Color surface = Color(0xFF151922);
  static const Color surfaceSoft = Color(0xFF1C2230);

  static const Color primary = Color(0xFF00D9E8);
  // Text and icons on a primary background: white on cyan is unreadable.
  static const Color onPrimary = background;
  static const Color primaryDark = Color(0xFF1677D2);
  static const Color accent = Color(0xFFF97316);

  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFAAB2C0);

  static const Color border = Color(0xFF2A3140);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}

// Resolve colors from the nearest theme, including dialogs and nested navigators.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required bool isLight}) : lightness = isLight ? 1 : 0;
  const AppPalette._(this.lightness);

  factory AppPalette.of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ??
      AppPalette(isLight: Theme.of(context).brightness == Brightness.light);

  final double lightness;
  bool get isLight => lightness >= 0.5;
  Color _color(Color dark, Color light) => Color.lerp(dark, light, lightness)!;
  Color get background => _color(AppColors.background, const Color(0xFFDEE6E4));
  Color get surface => _color(AppColors.surface, const Color(0xFFF1F4F3));
  Color get surfaceSoft =>
      _color(AppColors.surfaceSoft, const Color(0xFFD8E1DF));
  Color get primary => _color(AppColors.primary, const Color(0xFF0F6B65));
  Color get onPrimary => _color(AppColors.onPrimary, Colors.white);
  Color get primaryDark =>
      _color(AppColors.primaryDark, const Color(0xFF125CA4));
  Color get accent => _color(AppColors.accent, const Color(0xFFAD4508));
  Color get textPrimary =>
      _color(AppColors.textPrimary, const Color(0xFF1D2733));
  Color get textSecondary =>
      _color(AppColors.textSecondary, const Color(0xFF526071));
  Color get border => _color(AppColors.border, const Color(0xFFCCD5DF));
  Color get success => _color(AppColors.success, const Color(0xFF16743C));
  Color get warning => _color(AppColors.warning, const Color(0xFF865900));
  Color get error => _color(AppColors.error, const Color(0xFFBC2929));

  @override
  AppPalette copyWith({double? lightness}) =>
      AppPalette._(lightness ?? this.lightness);

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other == null
      ? this
      : AppPalette._(lightness + (other.lightness - lightness) * t);
}
