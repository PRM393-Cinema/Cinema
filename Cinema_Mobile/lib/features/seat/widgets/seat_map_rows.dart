import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/seat.dart';

// The seats of a room grouped by row, rows in order (A..Z, then AA) and seats
// by number: the order the API lists them in.
List<(String, List<Seat>)> seatRowsOf(Iterable<Seat> seats) {
  final rows = <String, List<Seat>>{};
  for (final seat in seats) {
    rows.putIfAbsent(seat.row, () => []).add(seat);
  }
  final keys = rows.keys.toList()
    ..sort(
      (a, b) => a.length != b.length ? a.length - b.length : a.compareTo(b),
    );
  return [
    for (final key in keys)
      (key, rows[key]!..sort((a, b) => a.number.compareTo(b.number))),
  ];
}

int widestRowOf(List<(String, List<Seat>)> rows) =>
    rows.fold(0, (widest, row) => math.max(widest, row.$2.length));

// Sizes a seat map so the widest row fits the screen: seats shrink on
// phones (down to [minSeat]) and grow up to [maxSeat] on larger screens.
class SeatMapLayout {
  const SeatMapLayout({required this.seatSize, required this.gap});

  factory SeatMapLayout.fit({
    required double maxWidth,
    required int seatsPerRow,
  }) {
    final seats = math.max(seatsPerRow, 1);
    final gap = maxWidth < 600 ? 6.0 : AppSpacing.md;
    final available =
        maxWidth -
        padding * 2 -
        (labelWidth + labelGap) * 2 -
        aisleAfter(seats).length * aisleWidth -
        gap * (seats - 1);

    return SeatMapLayout(
      seatSize: (available / seats).clamp(minSeat, maxSeat).toDouble(),
      gap: gap,
    );
  }

  static const padding = AppSpacing.md;
  static const labelWidth = 20.0;
  static const labelGap = 6.0;
  static const minSeat = 20.0;
  static const maxSeat = 44.0;
  static const aisleWidth = 12.0;

  static List<int> aisleAfter(int seats) => seats >= 14
      ? [4, seats - 4]
      : seats >= 8
      ? [seats ~/ 2]
      : const [];

  final double seatSize;
  final double gap;

  double seatsWidth(int seats) =>
      seats * seatSize +
      (seats - 1) * gap +
      aisleAfter(seats).length * aisleWidth;

  double mapWidth(int seats) {
    return seatsWidth(seats) + (labelWidth + labelGap) * 2 + padding * 2;
  }
}

// The rows of a seat map, lettered on both sides, with aisles in long rows.
// [seatBuilder] draws one seat at the layout's size.
class SeatMapRows extends StatelessWidget {
  const SeatMapRows({
    required this.rows,
    required this.layout,
    required this.seatBuilder,
    super.key,
  });

  final List<(String, List<Seat>)> rows;
  final SeatMapLayout layout;
  final Widget Function(Seat seat, double size) seatBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (rowKey, rowSeats) in rows)
          Padding(
            padding: EdgeInsets.only(bottom: layout.gap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RowLabel(label: rowKey),
                const SizedBox(width: SeatMapLayout.labelGap),
                for (final (index, seat) in rowSeats.indexed) ...[
                  if (index > 0)
                    SizedBox(
                      width:
                          layout.gap +
                          (SeatMapLayout.aisleAfter(rowSeats.length)
                                  .contains(index)
                              ? SeatMapLayout.aisleWidth
                              : 0),
                    ),
                  seatBuilder(seat, layout.seatSize),
                ],
                const SizedBox(width: SeatMapLayout.labelGap),
                _RowLabel(label: rowKey),
              ],
            ),
          ),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: SeatMapLayout.labelWidth,
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class SeatScreenIndicator extends StatelessWidget {
  const SeatScreenIndicator({required this.width, super.key});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(size: Size(width, 24), painter: _ScreenCurvePainter()),
        const SizedBox(height: AppSpacing.sm),
        const Text('SCREEN', style: AppTextStyles.caption),
      ],
    );
  }
}

class _ScreenCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withAlpha(128)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, 0, size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
