import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';
import '../payment_args.dart';

enum _Outcome { confirmed, refund, pending, failed }

class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  PaymentResultArgs? _args;
  PaymentInfo? _payment;
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (_args == null && args is PaymentResultArgs) {
      _args = args;
      _payment = args.payment;
      _load();
    }
  }

  // Verifies the payment with PayOS (unless already done) and reloads the
  // booking, whose status is the source of truth for the tickets.
  Future<void> _load({bool verifyAgain = false}) async {
    final args = _args;
    if (args == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var payment = verifyAgain ? null : _payment;
      if (payment == null) {
        try {
          payment = await widget.bookingRepository.verifyPayOsPayment(
            args.bookingId,
          );
        } on ApiException catch (error) {
          // 404: the booking has no PayOS payment; show the booking only.
          if (error.statusCode != 404) rethrow;
        }
      }

      final booking = await widget.bookingRepository.getBooking(args.bookingId);
      if (!mounted) return;

      setState(() {
        _payment = payment;
        _booking = booking;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  _Outcome _outcomeOf(Booking booking, PaymentInfo? payment) {
    if (booking.status == BookingStatus.confirmed) {
      return _Outcome.confirmed;
    }
    if (payment?.status == PaymentStatus.refundPending ||
        payment?.status == PaymentStatus.refunded) {
      return _Outcome.refund;
    }
    if (booking.status == BookingStatus.pending) {
      return _Outcome.pending;
    }
    return _Outcome.failed;
  }

  void _goHome() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _openMyBookings() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.myBookings,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Result'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: _goHome,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_args == null) {
      return const ErrorState(
        title: 'Payment not found',
        message: 'Open your booking from My Bookings to check its payment.',
      );
    }

    if (_isLoading) {
      return const LoadingState(message: 'Checking your payment...');
    }

    final booking = _booking;
    if (_errorMessage != null || booking == null) {
      return ErrorState(
        title: 'Unable to check the payment',
        message: _errorMessage ?? 'Please try again.',
        onRetry: () => _load(verifyAgain: true),
      );
    }

    final outcome = _outcomeOf(booking, _payment);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OutcomeHeader(outcome: outcome, booking: booking),
              const SizedBox(height: AppSpacing.xl),
              _TicketCard(booking: booking),
              const SizedBox(height: AppSpacing.xl),
              ..._actions(outcome, booking),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(_Outcome outcome, Booking booking) {
    return switch (outcome) {
      _Outcome.confirmed || _Outcome.refund => [
        AppButton(label: 'View my bookings', onPressed: _openMyBookings),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(label: 'Back to home', onPressed: _goHome),
      ],
      _Outcome.pending => [
        AppButton(
          label: 'Check again',
          onPressed: () => _load(verifyAgain: true),
        ),
        if (booking.isAwaitingPayment()) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: 'Continue payment',
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.payment,
              arguments: booking,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(label: 'Back to home', onPressed: _goHome),
      ],
      _Outcome.failed => [AppButton(label: 'Back to home', onPressed: _goHome)],
    };
  }
}

class _OutcomeHeader extends StatelessWidget {
  const _OutcomeHeader({required this.outcome, required this.booking});

  final _Outcome outcome;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final email = booking.customerEmail;

    final (icon, color, title, message) = switch (outcome) {
      _Outcome.confirmed => (
        Icons.check_circle_outline,
        AppColors.success,
        'Payment successful',
        email == null
            ? 'Your booking is confirmed. Your tickets have been emailed to you.'
            : 'Your booking is confirmed. Your tickets have been emailed to $email.',
      ),
      _Outcome.refund => (
        Icons.info_outline,
        AppColors.warning,
        'Payment received',
        'Your seats were released before the payment arrived, so a full refund '
            'of ${formatVnd(booking.totalAmount)} has been requested. '
            'We will email you once the money is transferred back.',
      ),
      _Outcome.pending => (
        Icons.hourglass_top_outlined,
        AppColors.warning,
        'Waiting for payment',
        'PayOS has not confirmed your payment yet. If you have paid, check again in a moment.',
      ),
      _Outcome.failed => (
        Icons.cancel_outlined,
        AppColors.error,
        'Payment not completed',
        booking.status == BookingStatus.expired
            ? 'The seat hold expired before the payment was completed.'
            : 'The payment was cancelled and your seats have been released.',
      ),
    };

    return Column(
      children: [
        Icon(icon, color: color, size: AppSpacing.xxxl * 1.5),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: AppTextStyles.heading1, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final showTime = booking.showTime;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${booking.bookingCode}', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Text(
              booking.movieTitle ?? 'Movie ticket',
              style: AppTextStyles.heading2,
            ),
            if (showTime != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(formatDateTime(showTime), style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Seats: ${booking.seatLabels}',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              formatVnd(booking.totalAmount),
              style: AppTextStyles.title.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
