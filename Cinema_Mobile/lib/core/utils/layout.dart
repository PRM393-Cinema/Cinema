import 'dart:math' as math;

import 'package:flutter/widgets.dart';

// Windows at least this wide (a computer) get the website layout: navigation
// at the top and pages in several columns. Narrower windows (phones) keep the
// app layout with the tab bar at the bottom.
const double desktopBreakpoint = 900;

bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

// Width of forms, cards and lists on wide web and desktop windows, the same
// as the payment and profile screens.
const double contentMaxWidth = 640;

// Width of website pages laid out in columns (booking details, tickets).
const double pageMaxWidth = 1200;

// Width of lists and messages on the website (notifications, payments).
const double readingMaxWidth = 880;

// How wide a page's content gets on the website. In the app layout every
// page uses the phone column ([contentMaxWidth]).
enum PageWidth { form, reading, page }

// Padding that keeps content at most [maxWidth] wide and centred, while the
// list, scroll view or bottom bar it pads still fills the window (so the mouse
// wheel scrolls anywhere and bar backgrounds reach the edges).
EdgeInsets centeredPadding(
  BuildContext context,
  double padding, {
  double maxWidth = contentMaxWidth,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final side = math.max(padding, (width - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, padding, side, padding);
}

// Padding of a page: a phone column in the app layout, the wider website
// column on a computer.
EdgeInsets pagePadding(BuildContext context, double padding) =>
    widthPadding(context, padding, PageWidth.page);

EdgeInsets widthPadding(
  BuildContext context,
  double padding,
  PageWidth width,
) => centeredPadding(
  context,
  padding,
  maxWidth: !isDesktopLayout(context)
      ? contentMaxWidth
      : switch (width) {
          PageWidth.form => contentMaxWidth,
          PageWidth.reading => readingMaxWidth,
          PageWidth.page => pageMaxWidth,
        },
);
