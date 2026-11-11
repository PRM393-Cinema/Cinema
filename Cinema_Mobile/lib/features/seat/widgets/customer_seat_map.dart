import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import 'seat_item.dart';
import 'seat_legend.dart';
import 'seat_map_rows.dart';
import 'seat_type_style.dart';

class CustomerSeatMap extends StatelessWidget {
  const CustomerSeatMap({
    required this.data,
    required this.showtime,
    required this.selectedSeatIds,
    this.onSeatTap,
    this.canSelect,
    this.compact = false,
    this.preview = false,
    super.key,
  });

  final ShowtimeSeatsData data;
  final Showtime showtime;
  final Set<int> selectedSeatIds;
  final bool Function(Seat)? canSelect;
  final bool compact;
  final bool preview;
  final void Function(Seat seat, SeatReservationStatus status)? onSeatTap;

  SeatItemState _itemStateOf(Seat seat, SeatReservationStatus status) {
    if (selectedSeatIds.contains(seat.id)) {
      return SeatItemState.selected;
    }
    if (status == SeatReservationStatus.available &&
        canSelect?.call(seat) == false) {
      return SeatItemState.booked;
    }
    return switch (status) {
      SeatReservationStatus.held => SeatItemState.held,
      SeatReservationStatus.booked => SeatItemState.booked,
      SeatReservationStatus.available => SeatItemState.available,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = seatRowsOf(data.seats);
    final seatsPerRow = widestRowOf(rows);
    final types = {for (final seat in data.seats) seat.type.toUpperCase()};
    // Prices tell the seat types apart only when they differ.
    final showPrices = seatPricesOf(showtime, types: types).length > 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: seatsPerRow,
          compact: compact,
        );
        final fitsScreen = layout.mapWidth(seatsPerRow) <= constraints.maxWidth;
        final contentWidth =
            constraints.maxWidth - layout.horizontalPadding * 2;
        final legend = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: SeatLegend(
            types: types,
            priceOf: showPrices ? showtime.priceOf : null,
          ),
        );

        Widget map(Widget? legend) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layout.horizontalPadding,
            vertical: compact ? AppSpacing.xs : SeatMapLayout.padding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeatScreenIndicator(width: layout.seatsWidth(seatsPerRow)),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              // Wraps instead of widening the column: the map is
              // laid out unconstrained, so a long line would push
              // the seats off-centre (large text sizes, narrow
              // phones).
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Text(
                  preview
                      ? '${rows.length} hàng · ${data.seats.length} ghế'
                      : '${rows.length} rows • ${data.seats.length} seats • Pinch to zoom',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.xl),
              SeatMapRows(
                rows: rows,
                layout: layout,
                seatBuilder: (seat, size) => SeatItem(
                  key: ValueKey(
                    '${preview ? 'preview' : 'customer'}-seat-${seat.id}',
                  ),
                  label: seat.number.toString(),
                  state: _itemStateOf(seat, data.statusOf(seat)),
                  type: seat.type,
                  size: size,
                  onTap: onSeatTap == null
                      ? null
                      : () => onSeatTap!(seat, data.statusOf(seat)),
                ),
              ),
              if (legend != null) ...[
                SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
                legend,
              ],
            ],
          ),
        );

        if (preview) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: math.max(
                constraints.maxWidth,
                layout.mapWidth(seatsPerRow),
              ),
              child: map(legend),
            ),
          );
        }

        Widget viewer(BoxConstraints box, {Widget? legend}) =>
            InteractiveViewer(
              minScale: fitsScreen ? 1 : 0.5,
              maxScale: 3,
              constrained: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: box.maxWidth,
                  minHeight: box.maxHeight,
                ),
                child: Center(child: map(legend)),
              ),
            );

        if (fitsScreen || compact) return viewer(constraints, legend: legend);
        // A map wider than the screen is panned: its key stays in view below
        // it instead of moving (and being cut off) with the seats.
        return Column(
          children: [
            Expanded(child: LayoutBuilder(builder: (_, box) => viewer(box))),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SeatMapLayout.padding,
              ),
              child: legend,
            ),
          ],
        );
      },
    );
  }
}
