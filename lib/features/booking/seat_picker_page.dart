import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/cinema_api.dart';
import '../../shared/widgets.dart';

class SeatPickerPage extends StatefulWidget {
  const SeatPickerPage({
    super.key,
    required this.api,
    required this.movie,
    required this.showtime,
    required this.onAuthenticate,
    required this.onBookingCreated,
  });
  final CinemaApi api;
  final Movie movie;
  final Showtime showtime;
  final Future<Map<String, dynamic>?> Function() onAuthenticate;
  final VoidCallback onBookingCreated;

  @override
  State<SeatPickerPage> createState() => _SeatPickerPageState();
}

class _SeatPickerPageState extends State<SeatPickerPage> {
  late Future<(List<Seat>, List<int>)> _seatData;
  List<Seat> _seats = [];
  final Set<int> _selected = {};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(
    () => _seatData =
        Future.wait([
          widget.api.seatsForRoom(widget.showtime.roomId),
          widget.api.occupiedSeats(widget.showtime.id),
        ]).then((values) {
          _seats = values[0] as List<Seat>;
          return (_seats, values[1] as List<int>);
        }),
  );

  Future<void> _continue() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (widget.api.user == null) {
        final user = await widget.onAuthenticate();
        if (user == null) return;
      }
      final selectedSeats = _seats
          .where((seat) => _selected.contains(seat.id))
          .toList();
      if (!mounted) return;
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: CinemaColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _BookingReview(
          movie: widget.movie,
          showtime: widget.showtime,
          seats: selectedSeats,
        ),
      );
      if (accepted != true) return;
      final booking = await widget.api.createBooking(
        userId: (widget.api.user!['userId'] as num).toInt(),
        showtimeId: widget.showtime.id,
        movieTitle: widget.movie.title,
        startTime: widget.showtime.start,
        seatIds: _selected.toList(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BookingCreatedDialog(booking: booking),
      );
      if (mounted) {
        widget.onBookingCreated();
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      if (mounted) _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chọn ghế'),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: const BoxDecoration(
          color: CinemaColors.surface,
          border: Border(top: BorderSide(color: CinemaColors.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selected.isEmpty
                            ? 'Chưa chọn ghế'
                            : '${_selected.length} ghế đã chọn',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: CinemaColors.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(widget.showtime.price * _selected.length),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 156,
                  child: ElevatedButton(
                    onPressed: _selected.isNotEmpty && !_submitting
                        ? _continue
                        : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Tiếp tục'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    body: FutureBuilder<(List<Seat>, List<int>)>(
      future: _seatData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: CinemaColors.gold),
          );
        if (snapshot.hasError)
          return MessageState(
            title: 'Không tải được sơ đồ ghế',
            detail: snapshot.error.toString(),
            action: 'Thử lại',
            onAction: _load,
          );
        final seats = snapshot.data!.$1;
        final occupied = snapshot.data!.$2.toSet();
        final rows = <String, List<Seat>>{};
        for (final seat in seats) {
          rows.putIfAbsent(seat.row, () => []).add(seat);
        }
        final sortedRows = rows.keys.toList()..sort();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              widget.movie.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              '${formatDateLabel(widget.showtime.start)} · ${formatTime(widget.showtime.start)} · Phòng ${widget.showtime.roomId}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: CinemaColors.muted),
            ),
            const SizedBox(height: 26),
            const _ScreenArc(),
            const SizedBox(height: 28),
            for (final row in sortedRows) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        row,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final seat
                                in (rows[row]!..sort(
                                  (a, b) => a.number.compareTo(b.number),
                                )))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _SeatButton(
                                  seat: seat,
                                  selected: _selected.contains(seat.id),
                                  unavailable: occupied.contains(seat.id),
                                  onTap: occupied.contains(seat.id)
                                      ? null
                                      : () => setState(
                                          () => _selected.contains(seat.id)
                                              ? _selected.remove(seat.id)
                                              : _selected.add(seat.id),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _SeatLegend(color: CinemaColors.line, label: 'Trống'),
                _SeatLegend(color: CinemaColors.ink, label: 'Đang chọn'),
                _SeatLegend(color: Color(0xFFB6B5B0), label: 'Đã giữ'),
                _SeatLegend(color: Color(0xFFFFEBC2), label: 'VIP'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              _InlineError(_error!),
            ],
          ],
        );
      },
    ),
  );
}

class _BookingReview extends StatelessWidget {
  const _BookingReview({
    required this.movie,
    required this.showtime,
    required this.seats,
  });
  final Movie movie;
  final Showtime showtime;
  final List<Seat> seats;

  @override
  Widget build(BuildContext context) {
    final total = showtime.price * seats.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: CinemaColors.line,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Xác nhận ghế',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CinemaColors.muted),
          ),
          const SizedBox(height: 18),
          for (final seat in seats)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: Text('Ghế ${seat.label}')),
                  Text(
                    formatMoney(showtime.price),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          const Divider(color: CinemaColors.line, height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tổng cộng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                formatMoney(total),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Giữ ghế và tiếp tục'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ghế được giữ trong 10 phút sau khi đặt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCreatedDialog extends StatelessWidget {
  const _BookingCreatedDialog({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.check_circle_outline,
      size: 40,
      color: CinemaColors.green,
    ),
    title: const Text('Đã giữ ghế cho bạn'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          booking.movieTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Mã giữ chỗ ${booking.code}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: CinemaColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '${booking.seats.join(', ')} · ${formatMoney(booking.amount)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (booking.expiresAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Giữ ghế đến ${formatTime(booking.expiresAt!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Xong'),
      ),
    ],
  );
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.seat,
    required this.selected,
    required this.unavailable,
    required this.onTap,
  });
  final Seat seat;
  final bool selected, unavailable;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final vip = seat.type.toUpperCase() != 'NORMAL';
    final bg = unavailable
        ? const Color(0xFFB6B5B0)
        : selected
        ? CinemaColors.ink
        : vip
        ? const Color(0xFFFFEBC2)
        : CinemaColors.surface;
    final fg = selected || unavailable ? Colors.white : CinemaColors.ink;
    return Semantics(
      button: true,
      enabled: !unavailable,
      selected: selected,
      label: 'Ghế ${seat.label}${unavailable ? ', đã được giữ' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 42,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: unavailable || selected
                  ? bg
                  : vip
                  ? CinemaColors.gold.withValues(alpha: .6)
                  : CinemaColors.line,
            ),
          ),
          child: Text(
            '${seat.number}',
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: CinemaColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ScreenArc extends StatelessWidget {
  const _ScreenArc();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 3,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: CinemaColors.gold,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 7),
      Text(
        'MÀN HÌNH',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(letterSpacing: 2, fontSize: 10),
      ),
    ],
  );
}
