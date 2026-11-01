import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';

import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/cinema_page.dart';
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
  Widget build(BuildContext context) => CinemaPage(
    title: 'Payment history',
    width: PageWidth.reading,
    child: _body(),
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
        padding: widthPadding(context, AppSpacing.lg, PageWidth.reading),
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
          final (label, color, icon) = switch (payment.status) {
            PaymentStatus.success => (
              'Paid',
              AppPalette.of(context).success,
              Icons.check_circle_outline,
            ),
            PaymentStatus.pending => (
              'Pending',
              AppPalette.of(context).warning,
              Icons.schedule_outlined,
            ),
            PaymentStatus.failed => (
              'Failed',
              AppPalette.of(context).error,
              Icons.error_outline,
            ),
            PaymentStatus.refundPending => (
              'Refund pending',
              AppPalette.of(context).warning,
              Icons.hourglass_top_rounded,
            ),
            PaymentStatus.refunded => (
              'Refunded',
              AppPalette.of(context).primary,
              Icons.undo_rounded,
            ),
            PaymentStatus.unknown => (
              'Unknown',
              AppPalette.of(context).textSecondary,
              Icons.help_outline,
            ),
          };
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.bookingDetail(payment.bookingId),
            ),
            child: CinemaPanel(
              surfaceOpacity: 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: color,
                          size: 28,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(icon, color: color, size: 20),
                            Text(
                              label,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    formatVnd(payment.amount),
                    style: AppTextStyles.display.copyWith(
                      color: AppPalette.of(context).primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    payment.paymentCode,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    formatDateTime(payment.createdAt),
                    style: AppTextStyles.bodySmall,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Divider(
                      height: 1,
                      color: AppPalette.of(context).border,
                    ),
                  ),
                  Text('Payment method', style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    payment.method?.trim().isNotEmpty == true
                        ? payment.method!
                        : 'Not specified',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (payment.transactionRef?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Transaction reference',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(
                      payment.transactionRef!,
                      style: AppTextStyles.body,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: AppPalette.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'View booking #${payment.bookingId}',
                          style: AppTextStyles.body.copyWith(
                            color: AppPalette.of(context).primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppPalette.of(context).primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
