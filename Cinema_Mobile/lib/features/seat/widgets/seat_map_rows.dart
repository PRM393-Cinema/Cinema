import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/seat.dart';
import 'seat_type_style.dart';

// The seats of a room grouped by row, rows in order (A..Z, then AA) and seats
// by number: the order the API lists them in. On a seat map ([sweetboxLast])
// rows of sweetbox (couple) seats go to the back of the room, as in the
// cinema.
List<(String, List<Seat>)> seatRowsOf(
  Iterable<Seat> seats, {
  bool sweetboxLast = true,
}) {
  final rows = <String, List<Seat>>{};
  for (final seat in seats) {
    rows.putIfAbsent(seat.row, () => []).add(seat);
  }
  bool back(String key) =>
      sweetboxLast && rows[key]!.every((seat) => seat.isSweetbox);
  final keys = rows.keys.toList()
    ..sort((a, b) {
      final order = (back(a) ? 1 : 0) - (back(b) ? 1 : 0);
      if (order != 0) return order;
      return a.length != b.length ? a.length - b.length : a.compareTo(b);
    });
  return [
    for (final key in keys)
      (key, rows[key]!..sort((a, b) => a.number.compareTo(b.number))),
  ];
}

// True when the seats on both sides of [index] are the two halves of one
// sweetbox.
bool _pairAt(List<Seat> seats, int index) =>
    index > 0 &&
    index < seats.length &&
    seats[index - 1].sweetboxPartnerIn([seats[index]]) != null;

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

  final double seatSize;
  final double gap;

  double seatsWidth(int seats) => seats * seatSize + (seats - 1) * gap;

  double mapWidth(int seats) {
    return seatsWidth(seats) + (labelWidth + labelGap) * 2 + padding * 2;
  }
}

// The rows of a seat map, lettered on both sides. Seats sit side by side
// with no aisle gaps, so the two seats of a sweetbox are never split; they
// are joined by a band. [seatBuilder] draws one seat at the layout's size.
class SeatMapRows extends StatelessWidget {
  const SeatMapRows({
    required this.rows,
    required this.layout,
    required this.seatBuilder,
    this.onRowTap,
    super.key,
  });

  final List<(String, List<Seat>)> rows;
  final SeatMapLayout layout;
  final Widget Function(Seat seat, double size) seatBuilder;

  // Makes the row letters tappable (the admin room map changes a whole row).
  final void Function(List<Seat> seats)? onRowTap;

  List<Widget> _seatsOf(List<Seat> seats) {
    final children = <Widget>[];
    for (var index = 0; index < seats.length; index++) {
      if (index > 0) children.add(SizedBox(width: layout.gap));
      final seat = seatBuilder(seats[index], layout.seatSize);
      if (!_pairAt(seats, index + 1)) {
        children.add(seat);
        continue;
      }
      index++;
      children.add(
        _Sweetbox(
          size: layout.seatSize,
          children: [
            seat,
            SizedBox(width: layout.gap),
            seatBuilder(seats[index], layout.seatSize),
          ],
        ),
      );
    }
    return children;
  }

  VoidCallback? _rowTap(List<Seat> seats) {
    final onRowTap = this.onRowTap;
    return onRowTap == null ? null : () => onRowTap(seats);
  }

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
                _RowLabel(label: rowKey, onTap: _rowTap(rowSeats)),
                const SizedBox(width: SeatMapLayout.labelGap),
                ..._seatsOf(rowSeats),
                const SizedBox(width: SeatMapLayout.labelGap),
                _RowLabel(label: rowKey, onTap: _rowTap(rowSeats)),
              ],
            ),
          ),
      ],
    );
  }
}

// The band behind the two seats of a sweetbox; it does not move the seats.
class _Sweetbox extends StatelessWidget {
  const _Sweetbox({required this.size, required this.children});

  final double size;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: sweetboxColor.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(math.min(AppRadius.sm, size / 5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final text = SizedBox(
      width: SeatMapLayout.labelWidth,
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: onTap == null ? AppColors.textPrimary : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
    if (onTap == null) return text;
    return Tooltip(
      message: 'Row $label',
      child: InkWell(
        key: ValueKey('rowLabel-$label'),
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: text,
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
