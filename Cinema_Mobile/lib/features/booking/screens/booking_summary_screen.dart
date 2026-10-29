import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking_draft.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/create_booking_request.dart';
import '../widgets/seat_hold_timer.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../seat/widgets/seat_type_style.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../data/models/concession.dart';
import '../widgets/concession_picker.dart';
import '../../../data/models/promotion.dart';
import '../widgets/promotion_box.dart';
import '../../../data/models/loyalty.dart';
import '../../profile/widgets/membership_card.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isSubmitting = false;
  bool _confirmingAge = false;
  String? _errorMessage;
  Booking? _heldBooking;
  bool _holdStarted = false;
  bool _isHolding = true;
  bool _openingPayment = false;
  bool _isLeaving = false;
  Timer? _holdTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final draft = ModalRoute.of(context)?.settings.arguments;
    if (!_holdStarted && draft is BookingDraft) {
      _holdStarted = true;
      _startHold(draft);
    }
  }

  Future<void> _releaseHold(Booking booking) async {
    try {
      await widget.bookingRepository.cancelBooking(booking.id);
    } on Object {
      // Offline or app closed: the server still releases the hold at expiresAt.
    }
  }

  Future<void> _leaveSummary() async {
    if (_isLeaving || _isSubmitting) return;
    setState(() => _isLeaving = true);
    final held = _heldBooking;
    if (held != null) await _releaseHold(held);
    if (!mounted) return;
    setState(() => _heldBooking = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    final booking = _heldBooking;
    if (booking != null && !_openingPayment) unawaited(_releaseHold(booking));
    super.dispose();
  }

  Future<void> _startHold(BookingDraft draft) async {
    setState(() {
      _isHolding = true;
      _errorMessage = null;
    });
    try {
      final booking = await widget.bookingRepository.createBooking(
        showtimeId: draft.showtime.id,
        seatIds: draft.seats.map((s) => s.id).toList(),
      );
      if (!mounted) {
        await _releaseHold(booking);
        return;
      }
      if (booking.expiresAt == null) {
        await _releaseHold(booking);
        throw const FormatException('Missing seat hold deadline.');
      }
      setState(() {
        _heldBooking = booking;
        _isHolding = false;
      });
      _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
        if (booking.isHoldExpired()) _holdTimer?.cancel();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isHolding = false);
      if (error.statusCode == 409) {
        await _showSeatsTakenDialog(error.message);
      } else {
        _showError(error.message);
      }
    } on Object {
      if (mounted) {
        setState(() => _isHolding = false);
        _showError('Unable to hold your seats. Please try again.');
      }
    }
  }

  // The snacks menu; empty when it cannot load (tickets still sell).
  List<ConcessionItem> _snacks = const [];
  final _snackQuantities = <int, int>{};

  // The ticket discount shown; the server works it out again when booking.
  PromotionQuote _promotion = PromotionQuote.none;
  String? _promoCode;

  // The member's points; null when they cannot load (no points used then).
  LoyaltyCard? _card;
  bool _usePoints = false;
  bool _useMemberGifts = false;

  @override
  void initState() {
    super.initState();
    _loadSnacks();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final card = await widget.bookingRepository.getMyLoyalty();
      if (mounted) setState(() => _card = card);
    } on Object {
      // Tickets can be booked without points.
    }
  }

  // The points used on an order of [orderAmount] (seats − discount + snacks).
  int _pointsFor(double orderAmount) =>
      _usePoints ? _card?.usableOn(orderAmount) ?? 0 : 0;

  Future<void> _loadSnacks() async {
    try {
      final snacks = await widget.bookingRepository.getConcessions();
      if (mounted) setState(() => _snacks = snacks);
    } on Object {
      // Tickets can be booked without snacks.
    }
  }

  // A restricted movie needs the viewer to confirm the age rule first; staff
  // may check ID at the entrance.
  Future<bool> _confirmAgeRating(AgeRating rating) async {
    if (!rating.restricted) return true;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderRadiusXl,
          side: const BorderSide(color: AppColors.border),
        ),
        scrollable: true,
        titlePadding: const EdgeInsets.all(AppSpacing.xl),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        actionsPadding: const EdgeInsets.all(AppSpacing.xl),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AgeRatingBadge(rating: rating, large: true),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text('AGE RATING', style: AppTextStyles.caption),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Before you book', style: AppTextStyles.heading2),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating == AgeRating.k
                    ? 'Viewers under 13 must watch with a parent or guardian.'
                    : 'This movie is only for viewers '
                          '${rating.meaning.toLowerCase()}.',
                style: AppTextStyles.body.copyWith(height: 1.5),
              ),
              if (rating != AgeRating.k) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  child: Text(
                    'Please bring your ID. Staff may check it at the entrance. '
                    'Tickets for underage viewers are non-refundable.',
                    style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    minimumSize: const Size(0, AppSpacing.xxxl),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  key: const Key('confirmAgeRating'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, AppSpacing.xxxl),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text(
                    'I understand',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _confirmBooking(BookingDraft draft, int usePoints) async {
    final held = _heldBooking;
    if (_isSubmitting ||
        _confirmingAge ||
        held == null ||
        held.isHoldExpired()) {
      return;
    }
    _confirmingAge = true;
    setState(() {
      _errorMessage = null;
    });

    try {
      if (!await _confirmAgeRating(draft.movie.ageRating) || !mounted) return;
      if (held.isHoldExpired()) return;
      setState(() => _isSubmitting = true);
      final booking = await widget.bookingRepository.updateBooking(
        held.id,
        CreateBookingRequest(
          showtimeId: draft.showtime.id,
          seatIds: draft.seats.map((seat) => seat.id).toList(),
          concessions: {
            for (final MapEntry(key: id, value: quantity)
                in _snackQuantities.entries)
              if (quantity > 0) id: quantity,
          },
          promotionCode: _useMemberGifts ? null : _promoCode,
          usePoints: _useMemberGifts ? 0 : usePoints,
          useMemberGifts: _useMemberGifts,
        ),
      );

      if (!mounted) return;

      // The seats are now held for this booking: leave the selection flow so
      // going back cannot create a second booking for the same seats.
      _openingPayment = true;
      Navigator.pushNamedAndRemoveUntil(
        context,
        booking.status == BookingStatus.confirmed
            ? AppRoutes.bookingDetail(booking.id)
            : AppRoutes.payment(booking.id),
        (route) => route.isFirst,
        arguments: booking,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        await _showSeatsTakenDialog(error.message);
        return;
      }
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    } finally {
      _confirmingAge = false;
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSeatsTakenDialog(String message) async {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Seats no longer available',
          style: AppTextStyles.title,
        ),
        content: Text(
          'Your selected seats could not be reserved. Please choose your seats again.\n\n$message',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Choose again'),
          ),
        ],
      ),
    );

    if (mounted) {
      await _leaveSummary();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! BookingDraft) {
      return CinemaPage(
        title: 'Booking Summary',
        child: const ErrorState(
          title: 'Draft not found',
          message: 'Please return and select your seats again.',
        ),
      );
    }

    final draft = args;
    final showtime = draft.showtime;
    final seatLabels = draft.seats.map((seat) => seat.label).join(', ');
    // Tickets by seat type (Standard, VIP, Sweetbox), each at its price.
    final ticketsByType = <String, int>{};
    for (final seat in draft.seats) {
      ticketsByType.update(
        seat.type.toUpperCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final ticketTypes = ticketsByType.keys.toList()
      ..sort((a, b) => seatTypes.indexOf(a).compareTo(seatTypes.indexOf(b)));

    final movieCard = _SummaryCard(
      title: 'Movie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgeRatingBadge(rating: draft.movie.ageRating),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(draft.movie.title, style: AppTextStyles.heading2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            text: formatLongDate(showtime.startTime),
          ),
          _DetailRow(
            icon: Icons.access_time_outlined,
            text: formatTime(showtime.startTime),
          ),
          _DetailRow(
            icon: Icons.meeting_room_outlined,
            text: showtime.roomLabel,
          ),
        ],
      ),
    );
    final seatsCard = _SummaryCard(
      title: 'Seats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seatLabels, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${draft.ticketCount} Ticket(s)',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
    final snacksTotalPrice = snacksTotal(_snacks, _snackQuantities);
    final pickedSnacks = [
      for (final snack in _snacks)
        if ((_snackQuantities[snack.id] ?? 0) > 0) snack,
    ];
    final snacksCard = _SummaryCard(
      title: 'Snacks & drinks',
      child: ConcessionPicker(
        items: _snacks,
        quantities: _snackQuantities,
        enabled: !_isSubmitting,
        onChanged: (id, quantity) =>
            setState(() => _snackQuantities[id] = quantity),
      ),
    );
    final promotionCard = _useMemberGifts
        ? const SizedBox.shrink()
        : _SummaryCard(
            title: 'Promotion',
            child: PromotionBox(
              quote: widget.bookingRepository.quotePromotion,
              showtimeId: showtime.id,
              tickets: draft.ticketCount,
              ticketAmount: draft.totalPrice,
              enabled: !_isSubmitting,
              onChanged: (quote, code) => setState(() {
                _promotion = quote;
                _promoCode = code;
              }),
            ),
          );
    final discount = _useMemberGifts ? 0.0 : _promotion.discount;
    final eligibleSeats =
        draft.seats
            .where(
              (s) =>
                  _card?.tier == MemberTier.vvip ||
                  s.type.toUpperCase() == 'VIP',
            )
            .map((s) => showtime.priceOf(s.type))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final eligibleCombos = [
      for (final snack in pickedSnacks)
        if (snack.name.toLowerCase().startsWith('combo'))
          for (var n = 0; n < (_snackQuantities[snack.id] ?? 0); n++)
            snack.price,
    ]..sort((a, b) => b.compareTo(a));
    final giftDiscount = _useMemberGifts
        ? eligibleSeats
                  .take(_card?.giftTickets ?? 0)
                  .fold<double>(0, (a, b) => a + b) +
              eligibleCombos
                  .take(_card?.giftCombos ?? 0)
                  .fold<double>(0, (a, b) => a + b)
        : 0.0;
    final orderAmount =
        draft.totalPrice -
        (_useMemberGifts ? giftDiscount : discount) +
        snacksTotalPrice;
    final usePoints = _pointsFor(orderAmount);
    final card = _card;
    final pointsCard = card == null
        ? null
        : _SummaryCard(
            title: 'Member points',
            child: Column(
              children: [
                if (card.giftRenewsAt != null)
                  SwitchListTile.adaptive(
                    key: const Key('useMemberGifts'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use membership gifts'),
                    subtitle: Text(
                      '${card.giftTickets} ${card.tier == MemberTier.vip ? 'VIP seat ticket(s)' : 'ticket(s)'} · ${card.giftCombos} combo(s)\nRenews ${formatDate(card.giftRenewsAt!)}',
                    ),
                    value: _useMemberGifts,
                    onChanged:
                        _isSubmitting ||
                            (card.giftTickets == 0 && card.giftCombos == 0)
                        ? null
                        : (value) => setState(() {
                            _useMemberGifts = value;
                            if (value) _usePoints = false;
                          }),
                  ),
                if (_useMemberGifts)
                  Text(
                    'Gift discount: ${formatVnd(giftDiscount)}. Promo codes and points are not combined.',
                    style: AppTextStyles.bodySmall,
                  ),
                if (!_useMemberGifts)
                  UsePointsTile(
                    card: card,
                    orderAmount: orderAmount,
                    value: _usePoints,
                    enabled: !_isSubmitting,
                    onChanged: (value) => setState(() => _usePoints = value),
                  ),
              ],
            ),
          );
    final priceCard = _SummaryCard(
      title: 'Price Details',
      child: Column(
        children: [
          for (final (index, type) in ticketTypes.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${ticketsByType[type]}x ${seatTypeLabel(type)} '
                      '(${formatVnd(showtime.priceOf(type))})',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatVnd(ticketsByType[type]! * showtime.priceOf(type)),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          if (giftDiscount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  const Expanded(child: Text('Membership gifts')),
                  Text(
                    '−${formatVnd(giftDiscount)}',
                    key: const Key('summaryGifts'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discount (${_promotion.name ?? 'Promotion'})',
                      style: AppTextStyles.body,
                    ),
                  ),
                  Text(
                    '−${formatVnd(discount)}',
                    key: const Key('summaryDiscount'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          if (usePoints > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$usePoints member points',
                      style: AppTextStyles.body,
                    ),
                  ),
                  Text(
                    '−${formatVnd(usePoints * pointValue)}',
                    key: const Key('summaryPoints'),
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          for (final snack in pickedSnacks)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_snackQuantities[snack.id]}x ${snack.name}',
                      style: AppTextStyles.body,
                    ),
                  ),
                  Text(
                    formatVnd(snack.price * _snackQuantities[snack.id]!),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: AppTextStyles.heading2),
              Text(
                formatVnd(orderAmount - usePoints * pointValue),
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    const holdNote = Text(
      'The same seat hold continues through payment. Confirming does not restart the timer.',
      style: AppTextStyles.bodySmall,
    );
    final error = _errorMessage;
    final held = _heldBooking;
    final expired = held?.isHoldExpired() ?? false;
    final confirmButton = AppButton(
      label: expired
          ? 'Choose seats again'
          : held == null && !_isHolding
          ? 'Retry seat hold'
          : 'Confirm Booking',
      useGradient: true,
      trailingIcon: Icons.arrow_forward_rounded,
      isLoading: _isSubmitting || _isHolding || _isLeaving,
      onPressed: _isSubmitting || _isHolding || _isLeaving
          ? null
          : expired
          ? _leaveSummary
          : held == null
          ? () => _startHold(draft)
          : () => _confirmBooking(draft, usePoints),
    );
    final desktop = isDesktopLayout(context);

    return PopScope(
      canPop: _heldBooking == null && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveSummary());
      },
      child: Scaffold(
        body: CinemaBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: pagePadding(context, AppSpacing.lg),
                  child: const CinemaPageHeader(title: 'Booking Summary'),
                ),
                Padding(
                  padding: pagePadding(context, AppSpacing.sm),
                  child: held == null
                      ? Text(
                          _isHolding
                              ? 'Holding your seats…'
                              : 'Your seats are not held.',
                          style: AppTextStyles.bodySmall,
                        )
                      : SeatHoldTimer(
                          remaining: held.expiresAt!.difference(DateTime.now()),
                          expired: expired,
                        ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: pagePadding(context, AppSpacing.xl),
                    // Website: the order with the price and Confirm next to it.
                    child: ResponsiveColumns(
                      main: [
                        movieCard,
                        const SizedBox(height: AppSpacing.xl),
                        seatsCard,
                        if (_snacks.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          snacksCard,
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        promotionCard,
                        if (pointsCard != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          pointsCard,
                        ],
                        if (!desktop) const SizedBox(height: AppSpacing.xl),
                      ],
                      side: [
                        priceCard,
                        const SizedBox(height: AppSpacing.lg),
                        holdNote,
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _ErrorBanner(message: error),
                        ],
                        if (desktop) ...[
                          const SizedBox(height: AppSpacing.xl),
                          confirmButton,
                        ],
                      ],
                    ),
                  ),
                ),
                if (!desktop)
                  Padding(
                    padding: centeredPadding(
                      context,
                      AppSpacing.lg,
                    ).copyWith(top: AppSpacing.sm),
                    child: confirmButton,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        CinemaPanel(
          surfaceOpacity: 0.8,
          child: SizedBox(width: double.infinity, child: child),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }
}
