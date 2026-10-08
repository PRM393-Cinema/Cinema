import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// Width of forms, cards and lists on wide web and desktop windows, the same
// as the payment and profile screens.
const double contentMaxWidth = 640;

// Padding that keeps content at most [contentMaxWidth] wide and centred,
// while the list, scroll view or bottom bar it pads still fills the window
// (so the mouse wheel scrolls anywhere and bar backgrounds reach the edges).
EdgeInsets centeredPadding(BuildContext context, double padding) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(padding, (width - contentMaxWidth) / 2);
  return EdgeInsets.fromLTRB(side, padding, side, padding);
}
