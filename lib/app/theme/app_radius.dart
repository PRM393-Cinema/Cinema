import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static BorderRadius borderRadiusSm = BorderRadius.circular(sm);
  static BorderRadius borderRadiusMd = BorderRadius.circular(md);
  static BorderRadius borderRadiusLg = BorderRadius.circular(lg);
  static BorderRadius borderRadiusXl = BorderRadius.circular(xl);
}
