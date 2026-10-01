import 'package:flutter/material.dart';

abstract final class CinemaColors {
  static const ink = Color(0xFF171923);
  static const paper = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const gold = Color(0xFFD6A64A);
  static const muted = Color(0xFF777985);
  static const line = Color(0xFFE8E5DE);
  static const green = Color(0xFF26765A);
}

ThemeData cinemaTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: CinemaColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: CinemaColors.ink,
    primary: CinemaColors.ink,
    secondary: CinemaColors.gold,
    surface: CinemaColors.surface,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CinemaColors.paper,
    foregroundColor: CinemaColors.ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CinemaColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    hintStyle: const TextStyle(color: CinemaColors.muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CinemaColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CinemaColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: CinemaColors.ink, width: 1.5),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: CinemaColors.ink,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFD5D4D0),
      disabledForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: CinemaColors.ink,
      fontSize: 29,
      height: 1.13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      color: CinemaColors.ink,
      fontSize: 23,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    ),
    titleLarge: TextStyle(
      color: CinemaColors.ink,
      fontSize: 19,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: CinemaColors.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(color: CinemaColors.ink, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: CinemaColors.ink, fontSize: 14, height: 1.45),
    bodySmall: TextStyle(color: CinemaColors.muted, fontSize: 12, height: 1.4),
  ),
);
