import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/seat.dart';
import '../../seat/widgets/seat_map_rows.dart';
import '../../seat/widgets/seat_type_style.dart';

enum _SeatState { free, held, sold, checkedIn }

// The seats of a showtime for staff: free seats by type, seats held for a
// booking that is not paid yet, sold seats and the seats of tickets already
// checked in. Tapping a taken seat opens its booking.
class ShowtimeSeatMap extends StatelessWidget {
  const ShowtimeSeatMap({
    required this.seats,
    required this.bookings,
    required this.onOpenBooking,
    super.key,
  });

  final List<Seat> seats;
  final List<ShowtimeSeatBooking> bookings;
  final ValueChanged<int> onOpenBooking;

  static _SeatState _stateOf(ShowtimeSeatBooking? booking) => switch (booking) {
    null => _SeatState.free,
    ShowtimeSeatBooking(checkedInAt: _?) => _SeatState.checkedIn,
    ShowtimeSeatBooking(status: BookingStatus.pending) => _SeatState.held,
    _ => _SeatState.sold,
  };

  @override
  Widget build(BuildContext context) {
    final bySeat = {for (final booking in bookings) booking.seatId: booking};
    final rows = seatRowsOf(seats);
    final widest = widestRowOf(rows);
    final counts = <_SeatState, int>{};
    for (final seat in seats) {
      counts.update(_stateOf(bySeat[seat.id]), (n) => n + 1, ifAbsent: () => 1);
    }
    int count(_SeatState state) => counts[state] ?? 0;
    final sold = count(_SeatState.sold) + count(_SeatState.checkedIn);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SeatMapLayout.fit(
          maxWidth: constraints.maxWidth,
          seatsPerRow: widest,
        );
        final map = Padding(
          padding: const EdgeInsets.all(SeatMapLayout.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeatScreenIndicator(width: layout.seatsWidth(widest)),
              const SizedBox(height: AppSpacing.xl),
              SeatMapRows(
                rows: rows,
                layout: layout,
                seatBuilder: (seat, size) {
                  final booking = bySeat[seat.id];
                  return _ShowtimeSeat(
                    key: ValueKey('showtimeSeat-${seat.label}'),
                    seat: seat,
                    booking: booking,
                    state: _stateOf(booking),
                    size: size,
                    onOpenBooking: onOpenBooking,
                  );
                },
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$sold of ${seats.length} seats sold • '
              '${count(_SeatState.checkedIn)} checked in • '
              '${count(_SeatState.held)} awaiting payment',
              key: const Key('showtimeSeatSummary'),
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            // Very wide rooms scroll sideways instead of shrinking seats
            // below a tappable size.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(child: map),
              ),
            ),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                _LegendEntry(
                  state: _SeatState.free,
                  label: 'Free (${count(_SeatState.free)})',
                ),
                _LegendEntry(
                  state: _SeatState.held,
                  label: 'Awaiting payment (${count(_SeatState.held)})',
                ),
                _LegendEntry(
                  state: _SeatState.sold,
                  label: 'Sold (${count(_SeatState.sold)})',
                ),
                _LegendEntry(
                  state: _SeatState.checkedIn,
                  label: 'Checked in (${count(_SeatState.checkedIn)})',
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// Free seats keep the light colours of their type; taken seats are solid, so
// a held seat does not look like a free VIP one.
(Color fill, Color border, Color text) _colorsOf(
  _SeatState state,
  String type,
) => switch (state) {
  _SeatState.free => seatTypeColors(type),
  _SeatState.held => (
    AppColors.warning,
    AppColors.warning,
    AppColors.background,
  ),
  _SeatState.sold => (
    AppColors.textSecondary,
    AppColors.textSecondary,
    AppColors.background,
  ),
  _SeatState.checkedIn => (
    AppColors.success,
    AppColors.success,
    AppColors.background,
  ),
};

class _ShowtimeSeat extends StatelessWidget {
  const _ShowtimeSeat({
    required this.seat,
    required this.booking,
    required this.state,
    required this.size,
    required this.onOpenBooking,
    super.key,
  });

  final Seat seat;
  final ShowtimeSeatBooking? booking;
  final _SeatState state;
  final double size;
  final ValueChanged<int> onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final (fill, border, text) = _colorsOf(state, seat.type);
    final radius = BorderRadius.circular(math.min(AppRadius.sm, size / 5));
    final booking = this.booking;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: Text(
        '${seat.number}',
        style: AppTextStyles.caption.copyWith(
          color: text,
          fontSize: size < 36 ? 10 : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (booking == null) {
      return Tooltip(
        message: '${seat.label} • ${seatTypeLabel(seat.type)} • free',
        child: tile,
      );
    }
    final status = switch (state) {
      _SeatState.held => 'awaiting payment',
      _SeatState.checkedIn => 'checked in',
      _ => 'sold',
    };
    return Tooltip(
      message: '${seat.label} • ${booking.bookingCode} • $status',
      child: InkWell(
        borderRadius: radius,
        onTap: () => onOpenBooking(booking.bookingId),
        child: tile,
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.state, required this.label});

  final _SeatState state;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fill, border, _) = _colorsOf(state, 'NORMAL');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// The customers of a showtime: each booking with its seats, and whether the
// customer has come in. Tapping one opens the booking.
class ShowtimeCustomerList extends StatelessWidget {
  const ShowtimeCustomerList({
    required this.bookings,
    required this.onOpenBooking,
    super.key,
  });

  final List<ShowtimeSeatBooking> bookings;
  final ValueChanged<int> onOpenBooking;

  // A2 before A10, rows in order.
  static int _compareSeats(String a, String b) {
    final pattern = RegExp(r'^([A-Z]+)(\d+)$');
    final ma = pattern.firstMatch(a);
    final mb = pattern.firstMatch(b);
    if (ma == null || mb == null) return a.compareTo(b);
    final byRow = ma[1]!.length != mb[1]!.length
        ? ma[1]!.length - mb[1]!.length
        : ma[1]!.compareTo(mb[1]!);
    return byRow != 0 ? byRow : int.parse(ma[2]!) - int.parse(mb[2]!);
  }

  @override
  Widget build(BuildContext context) {
    final byBooking = <int, List<ShowtimeSeatBooking>>{};
    for (final seat in bookings) {
      byBooking.putIfAbsent(seat.bookingId, () => []).add(seat);
    }
    final groups = byBooking.values.toList()
      ..forEach(
        (seats) =>
            seats.sort((a, b) => _compareSeats(a.seatLabel, b.seatLabel)),
      )
      ..sort((a, b) => _compareSeats(a.first.seatLabel, b.first.seatLabel));

    return Column(
      key: const Key('showtimeCustomers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Customers (${groups.length})', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.sm),
        if (groups.isEmpty)
          const Text('No tickets yet.', style: AppTextStyles.bodySmall),
        for (final seats in groups) _customer(seats),
      ],
    );
  }

  Widget _customer(List<ShowtimeSeatBooking> seats) {
    final booking = seats.first;
    final checkedInAt = booking.checkedInAt;
    final (icon, color, status) = checkedInAt != null
        ? (
            Icons.how_to_reg,
            AppColors.success,
            'Checked in ${formatTime(checkedInAt)}',
          )
        : booking.status == BookingStatus.pending
        ? (Icons.schedule, AppColors.warning, 'Awaiting payment')
        : booking.status == BookingStatus.refundPending
        ? (Icons.currency_exchange, AppColors.warning, 'Refund requested')
        : (
            Icons.local_activity_outlined,
            AppColors.textSecondary,
            'Paid, not in yet',
          );
    return ListTile(
      key: ValueKey('showtimeCustomer-${booking.bookingId}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        booking.customerEmail ??
            (booking.userId == null
                ? 'Walk-in guest'
                : 'Customer #${booking.userId}'),
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${seats.map((seat) => seat.seatLabel).join(', ')} • '
        '${booking.bookingCode} • $status',
        style: AppTextStyles.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onOpenBooking(booking.bookingId),
    );
  }
}
