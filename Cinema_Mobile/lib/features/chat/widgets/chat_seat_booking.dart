import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
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
import 'chat_seat_picker.dart';

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
    required this.showSeatPicker,
    required this.onSignIn,
    required this.onBack,
    required this.onReview,
    required this.onExpired,
    super.key,
  });

  final ChatSeatSelection selection;
  final bool authenticated;
  final CatalogRepository catalog;
  final BookingRepository bookings;
  final Future<List<Seat>?> Function(WidgetBuilder) showSeatPicker;
  final VoidCallback onSignIn;
  final VoidCallback onBack;
  final VoidCallback onReview;
  final ValueChanged<String> onExpired;

  @override
  State<ChatSeatBooking> createState() => _ChatSeatBookingState();
}

class _ChatSeatBookingState extends State<ChatSeatBooking>
    with AutomaticKeepAliveClientMixin<ChatSeatBooking> {
  BookingDraft? _show;
  ShowtimeSeatsData? _map;
  Booking? _hold;
  Uri? _paymentUrl;
  Timer? _timer;
  Timer? _expiryTimer;
  DateTime? _deadline;
  String? _message;
  bool _busy = false;
  bool _review = false;
  bool _picking = false;
  bool _paid = false;
  bool _expired = false;
  final _selected = <int>{};

  @override
  bool get wantKeepAlive => true;

  String get _expiryNotice => _hold == null
      ? 'Đã hết thời gian xác nhận. Yêu cầu đặt vé đã được hủy.'
      : 'Đã hết thời gian giữ ghế. Nếu đã thanh toán, hãy kiểm tra trạng thái.';

  @override
  void initState() {
    super.initState();
    if (widget.authenticated) _load();
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }

  void _stopCountdown() {
    _timer?.cancel();
    _expiryTimer?.cancel();
  }

  void _expire() {
    if (_expired) return;
    _stopCountdown();
    setState(() => _expired = true);
    widget.onExpired(_expiryNotice);
  }

  void _startCountdown(DateTime? deadline) {
    _stopCountdown();
    _deadline = deadline;
    _expired = false;
    if (deadline == null) return;
    _expiryTimer = Timer(deadline.difference(DateTime.now()), _expire);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  void _startReview() {
    _review = true;
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    final showtime = _show!.showtime.startTime;
    _startCountdown(showtime.isBefore(deadline) ? showtime : deadline);
  }

  List<Seat> get _chosen =>
      _map!.seats.where((seat) => _selected.contains(seat.id)).toList();

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

  Future<void> _load({bool prefill = true}) async {
    await _run(() async {
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
        _review = false;
        _startCountdown(null);
        if (valid) {
          _selected.addAll(proposed.map((seat) => seat.id));
          _startReview();
        }
        if (proposal != null && !valid) {
          _message = 'Ghế hoặc giá đã thay đổi. Hãy chọn lại ghế.';
        }
      });
      if (valid) widget.onReview();
    });
    if (mounted && _show != null && !_review && _message == null) {
      await _pickSeats(
        closeOnCancel: prefill && widget.selection.proposal == null,
      );
    }
  }

  Future<void> _pickSeats({bool closeOnCancel = false}) async {
    if (_picking || _busy || _hold != null || _expired) return;
    _picking = true;
    try {
      final seats = await widget.showSeatPicker(
        (_) => ChatSeatPicker(
          show: _show!,
          data: _map!,
          tickets: _selected.isEmpty
              ? widget.selection.tickets
              : _selected.length,
          selected: _selected,
        ),
      );
      if (!mounted || _expired) return;
      if (seats == null) {
        if (closeOnCancel) widget.onBack();
        return;
      }
      setState(() {
        _selected
          ..clear()
          ..addAll(seats.map((seat) => seat.id));
        _startReview();
        _message = null;
      });
      widget.onReview();
    } finally {
      _picking = false;
    }
  }

  Future<void> _confirm() => _run(() async {
    if (_hold != null || !_review || _selected.isEmpty || _expired) return;
    final deadline = _deadline!;
    if (!deadline.isAfter(DateTime.now())) {
      _expire();
      return;
    }
    final showtime = _show!.showtime;
    _stopCountdown();
    try {
      final booking = await widget.bookings.createBooking(
        showtimeId: showtime.id,
        seatIds: _selected.toList(),
      );
      if (mounted) setState(() => _hold = booking);
    } finally {
      if (mounted) {
        _startCountdown(_hold == null ? deadline : _hold!.expiresAt);
      }
    }
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
      if (_paid) _stopCountdown();
      if (!_paid) _message = 'PayOS chưa xác nhận thanh toán.';
    });
  });

  Future<void> _cancel(Booking booking) => _run(() async {
    await widget.bookings.cancelBooking(booking.id);
    if (mounted) widget.onBack();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final activeHold = _hold != null && !_expired && !_paid;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: CinemaPanel(
        key: const Key('chatSeatBooking'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _hold != null
                        ? 'Giữ ghế'
                        : _review
                        ? 'Confirm Booking'
                        : 'Chọn ghế trong chat',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!activeHold)
                  IconButton(
                    onPressed: _busy ? null : widget.onBack,
                    tooltip: 'Đóng thẻ đặt vé',
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
              if (_review)
                ..._reviewWidgets(draft)
              else
                OutlinedButton(
                  onPressed: _busy ? null : _pickSeats,
                  child: const Text('Mở sơ đồ ghế'),
                ),
            ] else if (!_busy)
              OutlinedButton(
                onPressed: () => _load(prefill: false),
                child: const Text('Tải lại ghế'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expiredStatus() => Semantics(
    liveRegion: true,
    child: Text(
      _expiryNotice,
      style: TextStyle(color: AppPalette.of(context).error),
    ),
  );

  List<Widget> _reviewWidgets(BookingDraft draft) => [
    Text('Ghế ${_chosen.map((seat) => seat.label).join(', ')}'),
    Text(
      'Tiền vé dự kiến ${formatVnd(_chosen.fold<double>(0, (sum, seat) => sum + draft.showtime.priceOf(seat.type)))}',
    ),
    const SizedBox(height: AppSpacing.sm),
    if (_expired)
      _expiredStatus()
    else ...[
      Text(
        'Chờ xác nhận · ${formatCountdown(_deadline!.difference(DateTime.now()))}',
        style: TextStyle(color: AppPalette.of(context).textSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      _reviewActions(),
      if (_message != null)
        TextButton(
          onPressed: _busy ? null : () => _load(prefill: false),
          child: const Text('Tải lại ghế'),
        ),
    ],
  ];

  static const _actionStyle = ButtonStyle(
    visualDensity: VisualDensity.standard,
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
  );

  Widget _actionRow(Widget first, Widget second) => IntrinsicHeight(
    child: Row(
      spacing: AppSpacing.sm,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        Expanded(child: second),
      ],
    ),
  );

  Widget _reviewActions() => _actionRow(
    FilledButton(
      key: const Key('confirmChatBooking'),
      style: _actionStyle,
      onPressed: _busy ? null : _confirm,
      child: const Text('Xác nhận giữ ghế', textAlign: TextAlign.center),
    ),
    OutlinedButton(
      style: _actionStyle,
      onPressed: _busy ? null : _pickSeats,
      child: const Text('Đổi ghế'),
    ),
  );

  List<Widget> _holdWidgets(Booking booking) {
    final expired = _expired || booking.isHoldExpired();
    final remaining = booking.expiresAt?.difference(DateTime.now());
    final colors = AppPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final total = formatVnd(booking.totalAmount);
    final verifyButton = OutlinedButton(
      style: _actionStyle,
      onPressed: _busy ? null : () => _verifyPayment(booking),
      child: const Text('Kiểm tra thanh toán', textAlign: TextAlign.center),
    );
    return [
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Mã đơn ${booking.bookingCode}',
        style: theme.bodySmall?.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Text('Ghế ${booking.seats.map((seat) => seat.seatLabel).join(', ')}'),
          Text('Tổng $total', style: theme.titleSmall),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (_paid)
        const Text('Đã thanh toán')
      else ...[
        if (expired)
          _expiredStatus()
        else
          Row(
            spacing: AppSpacing.xs,
            children: [
              Icon(Icons.timer_outlined, size: 18, color: colors.primary),
              Expanded(
                child: Text(
                  remaining == null
                      ? 'Ghế đang được giữ để thanh toán'
                      : 'Còn ${formatCountdown(remaining)} để thanh toán',
                  style: theme.bodySmall?.copyWith(
                    color:
                        remaining != null &&
                            remaining < const Duration(minutes: 2)
                        ? colors.warning
                        : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        if (!expired)
          FilledButton(
            style: _actionStyle,
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
        if (!expired) const SizedBox(height: AppSpacing.sm),
        if (expired)
          verifyButton
        else
          _actionRow(
            verifyButton,
            OutlinedButton(
              style: _actionStyle.copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? null
                      : colors.error,
                ),
              ),
              onPressed: _busy ? null : () => _cancel(booking),
              child: const Text('Hủy giữ ghế', textAlign: TextAlign.center),
            ),
          ),
      ],
    ];
  }
}
