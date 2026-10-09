import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/booking_repository.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({required this.bookingRepository, super.key});
  final BookingRepository bookingRepository;
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<PaymentInfo> _payments = const [];
  bool _started = false;
  bool _loading = true;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final userId = SessionProvider.of(context).user?.userId;
    if (userId == null) {
      setState(() {
        _error = 'Please sign in to see your payments.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = _payments.isEmpty;
      _error = null;
    });
    try {
      final payments = await widget.bookingRepository.getMyPayments(userId);
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load payments. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment history')),
    body: CinemaBackground(child: _body()),
  );

  Widget _body() {
    if (_loading) return const LoadingState(message: 'Loading payments...');
    if (_error != null) {
      return ErrorState(
        title: 'Unable to load payments',
        message: _error!,
        onRetry: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centeredPadding(context, AppSpacing.lg),
        itemCount: _payments.isEmpty ? 1 : _payments.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (_payments.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Your payment history will appear here.',
            );
          }
          final payment = _payments[index];
          final (label, color) = switch (payment.status) {
            PaymentStatus.success => ('Paid', AppColors.success),
            PaymentStatus.pending => ('Pending', AppColors.warning),
            PaymentStatus.failed => ('Failed', AppColors.error),
            PaymentStatus.refundPending => (
              'Refund pending',
              AppColors.warning,
            ),
            PaymentStatus.refunded => ('Refunded', AppColors.primary),
            PaymentStatus.unknown => ('Unknown', AppColors.textSecondary),
          };
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.bookingDetail(payment.bookingId),
            ),
            child: CinemaPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          payment.paymentCode,
                          style: AppTextStyles.title,
                        ),
                      ),
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    formatVnd(payment.amount),
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Booking #${payment.bookingId} · ${payment.method ?? 'Payment'}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    formatDateTime(payment.createdAt),
                    style: AppTextStyles.caption,
                  ),
                  if (payment.transactionRef != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      'Transaction: ${payment.transactionRef}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
