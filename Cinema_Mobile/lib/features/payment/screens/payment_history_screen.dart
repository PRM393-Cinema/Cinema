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
  Widget build(BuildContext context) {
    return CinemaPage(
      title: 'Payment history',
      subtitle: _loading
          ? 'Loading payments...'
          : formatCount(_payments.length, 'transaction'),
      width: PageWidth.page,
      child: _body(),
    );
  }

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
      child: isDesktopLayout(context)
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context, AppSpacing.lg),
              children: [
                if (_payments.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payments yet',
                    message: 'Your payment history will appear here.',
                  )
                else
                  _PaymentTable(payments: _payments),
              ],
            )
          : ListView.separated(
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
                final (label, color, icon) = _paymentStatus(
                  context,
                  payment.status,
                );
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
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
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
                        if (payment.transactionRef?.trim().isNotEmpty ==
                            true) ...[
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

(String, Color, IconData) _paymentStatus(
  BuildContext context,
  PaymentStatus status,
) => switch (status) {
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

class _PaymentTable extends StatelessWidget {
  const _PaymentTable({required this.payments});

  final List<PaymentInfo> payments;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth.clamp(860 * scale, double.infinity),
            child: SelectionArea(
              child: DataTable(
                key: const Key('paymentHistoryTable'),
                horizontalMargin: AppSpacing.lg,
                columnSpacing: AppSpacing.lg,
                headingRowHeight: 40 * scale,
                dataRowMinHeight: 56 * scale,
                dataRowMaxHeight: double.infinity,
                dividerThickness: 1,
                border: TableBorder(
                  horizontalInside: BorderSide(color: colors.border),
                ),
                headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surface,
                ),
                headingTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                dataTextStyle: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
                columns: const [
                  DataColumn(
                    label: Expanded(child: Text('Payment ID')),
                    columnWidth: FlexColumnWidth(3.3),
                  ),
                  DataColumn(
                    label: Expanded(child: Text('Date')),
                    columnWidth: FlexColumnWidth(1.4),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text('Amount', textAlign: TextAlign.end),
                    ),
                    numeric: true,
                    columnWidth: FlexColumnWidth(1.4),
                  ),
                  DataColumn(
                    label: Expanded(child: Text('Method', softWrap: true)),
                    columnWidth: FlexColumnWidth(1),
                  ),
                  DataColumn(
                    label: Expanded(child: Text('Status')),
                    columnWidth: FlexColumnWidth(1.5),
                  ),
                  DataColumn(
                    label: Expanded(child: Text('Action')),
                    columnWidth: FlexColumnWidth(1.6),
                  ),
                ],
                rows: [
                  for (final payment in payments)
                    DataRow(
                      key: ValueKey('paymentRow-${payment.id}'),
                      cells: [
                        DataCell(
                          Tooltip(
                            message: [
                              payment.paymentCode,
                              if (payment.transactionRef?.trim().isNotEmpty ==
                                  true)
                                'Transaction reference: ${payment.transactionRef}',
                            ].join('\n'),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.paymentCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (payment.transactionRef?.trim().isNotEmpty ==
                                    true)
                                  Text(
                                    'Ref: ${payment.transactionRef}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatDate(payment.createdAt)),
                              Text(
                                formatTime(payment.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            formatVnd(payment.amount),
                            softWrap: true,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            payment.method?.trim().isNotEmpty == true
                                ? payment.method!
                                : 'Not specified',
                            softWrap: true,
                          ),
                        ),
                        DataCell(_status(context, payment.status)),
                        DataCell(
                          TextButton(
                            key: ValueKey('paymentBooking-${payment.id}'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              minimumSize: const Size(0, 40),
                              textStyle: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.bookingDetail(payment.bookingId),
                            ),
                            child: const Text('View booking', softWrap: true),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context, PaymentStatus status) {
    final (label, color, _) = _paymentStatus(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        softWrap: true,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
