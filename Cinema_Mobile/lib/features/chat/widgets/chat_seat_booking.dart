import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/payment.dart';
import '../../../data/models/seat.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/services/chat_service.dart';
import '../../booking/widgets/seat_hold_timer.dart';

typedef ChatSeatSelection = ({
  int showtimeId,
  int tickets,
  ChatBookingProposal? proposal,
});

class ChatSeatBooking extends StatefulWidget {
  const ChatSeatBooking({
    required this.selection,
    required this.authenticated,
    required this.catalog,
    required this.bookings,
    required this.onSignIn,
    required this.onBack,
    super.key,
  });

  final ChatSeatSelection selection;
  final bool authenticated;
  final CatalogRepository catalog;
  final BookingRepository bookings;
  final VoidCallback onSignIn;
  final VoidCallback onBack;

  @override
  State<ChatSeatBooking> createState() => _ChatSeatBookingState();
}

class _ChatSeatBookingState extends State<ChatSeatBooking> {
  BookingDraft? _show;
  ShowtimeSeatsData? _map;
  Booking? _hold;
  Uri? _paymentUrl;
  Timer? _timer;
  String? _message;
  bool _busy = false;
  bool _review = false;
  bool _paid = false;
  late int _tickets = widget.selection.tickets;
  String? _row;
  final _selected = <int>{};

  @override
  void initState() {
    super.initState();
    if (widget.authenticated) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _free(Seat seat) =>
      _map!.statusOf(seat) == SeatReservationStatus.available;

  bool _selectable(Seat seat) {
    final partner = seat.sweetboxPartnerIn(_map!.seats);
    return _free(seat) &&
        (!seat.isSweetbox || (partner != null && _free(partner)));
  }

  List<Seat> get _chosen =>
      _map!.seats.where((seat) => _selected.contains(seat.id)).toList();

  List<Seat> get _suggestion {
    final seats = _map!.seats;
    final ordered = seats.where(_free).toList()
      ..sort((a, b) {
        final row = a.row.compareTo(b.row);
        return row == 0 ? a.number.compareTo(b.number) : row;
      });
    for (final type in ['NORMAL', 'VIP', 'SWEETBOX']) {
      final matching = ordered.where((seat) => seat.type == type).toList();
      for (var i = 0; i + _tickets <= matching.length; i++) {
        final group = matching.sublist(i, i + _tickets);
        if (group.last.row == group.first.row &&
            group.last.number - group.first.number == _tickets - 1 &&
            group.every(
              (s) => !s.isSweetbox || s.sweetboxPartnerIn(group) != null,
            )) {
          return group;
        }
      }
    }
    return const [];
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Object {
      if (mounted) {
        setState(() => _message = 'Không thể tiếp tục. Bạn thử lại nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load({bool prefill = true}) => _run(() async {
    final proposal = prefill ? widget.selection.proposal : null;
    if (proposal != null && !proposal.expiresAt.isAfter(DateTime.now())) {
      throw const FormatException('Đề xuất đã hết hạn. Hãy chọn lại ghế.');
    }
    final showtime = await widget.catalog.getShowtime(
      widget.selection.showtimeId,
    );
    if (!showtime.isOpen || !showtime.startTime.isAfter(DateTime.now())) {
      throw const FormatException('Suất chiếu đã đóng hoặc đã bắt đầu.');
    }
    final movie = await widget.catalog.getMovie(showtime.movieId);
    final map = await widget.catalog.getSeatMap(showtime);
    if (!mounted) return;
    final proposed = map.seats
        .where((s) => proposal?.seatIds.contains(s.id) ?? false)
        .toList();
    final draft = BookingDraft(
      movie: movie,
      showtime: showtime,
      seats: proposed,
    );
    final valid =
        proposal != null &&
        proposal.movieId == movie.id &&
        proposed.length == proposal.seatIds.length &&
        proposed.every(
          (s) =>
              map.statusOf(s) == SeatReservationStatus.available &&
              (!s.isSweetbox || s.sweetboxPartnerIn(proposed) != null),
        ) &&
        (draft.totalPrice - proposal.total).abs() <= .01;
    setState(() {
      _show = draft;
      _map = map;
      _selected.clear();
      _review = valid;
      _row = null;
      if (valid) _selected.addAll(proposed.map((seat) => seat.id));
      if (proposal != null && !valid) {
        _message = 'Ghế hoặc giá đã thay đổi. Hãy chọn lại ghế.';
      }
    });
  });

  void _toggle(Seat seat) {
    final partner = seat.sweetboxPartnerIn(_map!.seats);
    if (seat.isSweetbox && (partner == null || !_free(partner))) return;
    final ids = {seat.id, if (partner != null) partner.id};
    setState(() {
      _message = null;
      if (_selected.contains(seat.id)) {
        _selected.removeAll(ids);
      } else if (_selected.length + ids.length <= _tickets) {
        _selected.addAll(ids);
      } else {
        _message = 'Bạn đã chọn đủ $_tickets ghế. Bỏ chọn ghế để đổi.';
      }
    });
  }

  void _changeTickets(int count) => setState(() {
    _tickets = count;
    _selected.clear();
    _message = null;
  });

  Future<void> _confirm() => _run(() async {
    if (_hold != null || !_review || _selected.length != _tickets) return;
    final showtime = _show!.showtime;
    if (!showtime.startTime.isAfter(DateTime.now())) {
      throw const FormatException('Suất chiếu đã bắt đầu.');
    }
    final booking = await widget.bookings.createBooking(
      showtimeId: showtime.id,
      seatIds: _selected.toList(),
    );
    if (!mounted) return;
    setState(() => _hold = booking);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hold == null || _paid) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (_hold!.isHoldExpired()) timer.cancel();
    });
  });

  Future<void> _startPayment(Booking booking) => _run(() async {
    final checkout = await widget.bookings.startPayOsCheckout(booking);
    if (!mounted) return;
    final url = Uri.tryParse(checkout.checkoutUrl ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const FormatException(
        'Hãy kiểm tra trạng thái thanh toán của đơn này.',
      );
    }
    setState(() => _paymentUrl = url);
  });

  Future<void> _verifyPayment(Booking booking) => _run(() async {
    final payment = await widget.bookings.verifyPayOsPayment(booking.id);
    if (!mounted) return;
    setState(() {
      _paid = payment.status == PaymentStatus.success;
      if (!_paid) _message = 'PayOS chưa xác nhận thanh toán.';
    });
  });

  Future<void> _cancel(Booking booking) => _run(() async {
    await widget.bookings.cancelBooking(booking.id);
    if (mounted) widget.onBack();
  });

  @override
  Widget build(BuildContext context) {
    return CinemaPanel(
      key: const Key('chatSeatBooking'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn ghế trong chat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _busy ? null : widget.onBack,
                tooltip: 'Quay lại chat',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: TextStyle(color: AppPalette.of(context).error),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (!widget.authenticated) ...[
            const Text('Đăng nhập để chọn ghế và đặt vé.'),
            FilledButton(
              onPressed: widget.onSignIn,
              child: const Text('Đăng nhập'),
            ),
          ] else if (_hold case final booking?)
            ..._holdWidgets(booking)
          else if (_show case final draft?) ...[
            Text(draft.movie.title),
            Text(
              '${formatDateTime(draft.showtime.startTime)} · ${draft.showtime.roomLabel}',
            ),
            const SizedBox(height: 10),
            if (_review) ..._reviewWidgets(draft) else ..._seatWidgets(),
          ] else if (!_busy)
            OutlinedButton(
              onPressed: () => _load(prefill: false),
              child: const Text('Tải lại ghế'),
            ),
        ],
      ),
    );
  }

  List<Widget> _seatWidgets() {
    final suggestion = _suggestion;
    final rows = _map!.seats.map((seat) => seat.row).toSet().toList()..sort();
    final row = _row ?? (suggestion.firstOrNull?.row ?? rows.firstOrNull);
    return [
      Row(
        children: [
          const Expanded(child: Text('Số vé')),
          IconButton(
            tooltip: 'Giảm số vé',
            onPressed: _busy || _tickets == 1
                ? null
                : () => _changeTickets(_tickets - 1),
            icon: const Icon(Icons.remove),
          ),
          Text('$_tickets'),
          IconButton(
            tooltip: 'Tăng số vé',
            onPressed: _busy || _tickets == 8
                ? null
                : () => _changeTickets(_tickets + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      if (suggestion.isNotEmpty)
        OutlinedButton(
          key: const Key('chatUseSuggestedSeats'),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _selected
                    ..clear()
                    ..addAll(suggestion.map((seat) => seat.id));
                  _row = suggestion.first.row;
                  _message = null;
                }),
          child: Text(
            'Gợi ý ${suggestion.map((seat) => seat.label).join(', ')}',
          ),
        )
      else
        const Text(
          'Chưa có cụm ghế liền nhau phù hợp. Bạn có thể tự chọn ghế.',
        ),
      if (rows.length > 1)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in rows)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Hàng $value'),
                    selected: row == value,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _row = value),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        children: [
          for (final seat in _map!.seats.where((seat) => seat.row == row))
            FilterChip(
              key: ValueKey('chat-seat-${seat.id}'),
              label: Text(seat.label),
              tooltip:
                  '${seat.type} · ${formatVnd(_show!.showtime.priceOf(seat.type))}',
              selected: _selected.contains(seat.id),
              onSelected: !_busy && _selectable(seat)
                  ? (_) => _toggle(seat)
                  : null,
            ),
        ],
      ),
      Text(
        '${_selected.length}/$_tickets ghế · ${_chosen.map((s) => s.label).join(', ')}',
      ),
      FilledButton(
        onPressed: !_busy && _selected.length == _tickets
            ? () => setState(() {
                _review = true;
                _message = null;
              })
            : null,
        child: const Text('Xem lại đặt vé'),
      ),
    ];
  }

  List<Widget> _reviewWidgets(BookingDraft draft) => [
    Text('Ghế ${_chosen.map((seat) => seat.label).join(', ')}'),
    Text(
      'Tiền vé dự kiến ${formatVnd(_chosen.fold<double>(0, (sum, seat) => sum + draft.showtime.priceOf(seat.type)))}',
    ),
    FilledButton(
      key: const Key('confirmChatBooking'),
      onPressed: _busy ? null : _confirm,
      child: const Text('Xác nhận giữ ghế'),
    ),
    TextButton(
      onPressed: _busy ? null : () => setState(() => _review = false),
      child: const Text('Đổi ghế'),
    ),
    if (_message != null)
      TextButton(
        onPressed: _busy ? null : () => _load(prefill: false),
        child: const Text('Tải lại ghế'),
      ),
  ];

  List<Widget> _holdWidgets(Booking booking) {
    final expired = booking.isHoldExpired();
    return [
      Text('Mã đơn ${booking.bookingCode}'),
      Text('Ghế ${booking.seats.map((seat) => seat.seatLabel).join(', ')}'),
      Text('Tổng tiền ${formatVnd(booking.totalAmount)}'),
      if (_paid)
        const Text('Đã thanh toán')
      else ...[
        SeatHoldTimer(
          remaining: booking.expiresAt?.difference(DateTime.now()),
          expired: expired,
        ),
        if (!expired)
          FilledButton(
            onPressed: _busy
                ? null
                : _paymentUrl == null
                ? () => _startPayment(booking)
                : () => _run(() async {
                    if (!await launchUrl(
                      _paymentUrl!,
                      webOnlyWindowName: '_blank',
                    )) {
                      throw const FormatException('Không mở được trang PayOS.');
                    }
                  }),
            child: Text(_paymentUrl == null ? 'Tạo link PayOS' : 'Mở PayOS'),
          ),
        TextButton(
          onPressed: _busy ? null : () => _verifyPayment(booking),
          child: const Text('Kiểm tra thanh toán'),
        ),
        if (!expired)
          TextButton(
            onPressed: _busy ? null : () => _cancel(booking),
            child: const Text('Hủy giữ ghế'),
          ),
      ],
    ];
  }
}
