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
import '../../../data/repositories/booking_repository.dart';
import '../../seat/widgets/seat_type_style.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../data/models/concession.dart';
import '../widgets/concession_picker.dart';
import '../../../data/models/promotion.dart';
import '../widgets/promotion_box.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  // The snacks menu; empty when it cannot load (tickets still sell).
  List<ConcessionItem> _snacks = const [];
  final _snackQuantities = <int, int>{};

  // The ticket discount shown; the server works it out again when booking.
  PromotionQuote _promotion = PromotionQuote.none;
  String? _promoCode;

  @override
  void initState() {
    super.initState();
    _loadSnacks();
  }

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
        title: Row(
          children: [
            AgeRatingBadge(rating: rating, large: true),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Age rating')),
          ],
        ),
        content: Text(
          rating == AgeRating.k
              ? 'This movie is rated K: viewers under 13 must watch with a '
                    'parent or guardian.'
              : 'This movie is rated ${rating.code}: only for viewers '
                    '${rating.meaning.toLowerCase()}. Staff may ask for ID at '
                    'the entrance, and tickets of underage viewers are not '
                    'refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          TextButton(
            key: const Key('confirmAgeRating'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  Future<void> _confirmBooking(BookingDraft draft) async {
    if (!await _confirmAgeRating(draft.movie.ageRating) || !mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final booking = await widget.bookingRepository.createBooking(
        showtimeId: draft.showtime.id,
        seatIds: draft.seats.map((seat) => seat.id).toList(),
        concessions: {
          for (final MapEntry(key: id, value: quantity)
              in _snackQuantities.entries)
            if (quantity > 0) id: quantity,
        },
        promotionCode: _promoCode,
      );

      if (!mounted) return;

      // The seats are now held for this booking: leave the selection flow so
      // going back cannot create a second booking for the same seats.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.payment(booking.id),
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
          'Some of your seats were just taken by another customer. Please choose your seats again.\n\n$message',
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
      Navigator.pop(context, true);
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
    final promotionCard = _SummaryCard(
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
    final discount = _promotion.discount;
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
                formatVnd(draft.totalPrice - discount + snacksTotalPrice),
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
      'Your seats will be held for 10 minutes while you pay with PayOS.',
      style: AppTextStyles.bodySmall,
    );
    final error = _errorMessage;
    final confirmButton = AppButton(
      label: 'Confirm Booking',
      useGradient: true,
      trailingIcon: Icons.arrow_forward_rounded,
      isLoading: _isSubmitting,
      onPressed: _isSubmitting ? null : () => _confirmBooking(draft),
    );
    final desktop = isDesktopLayout(context);

    return Scaffold(
      body: CinemaBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: pagePadding(context, AppSpacing.lg),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Booking Summary', style: AppTextStyles.heading2),
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
