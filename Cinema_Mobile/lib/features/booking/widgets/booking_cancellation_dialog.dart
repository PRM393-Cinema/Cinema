import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../auth/widgets/auth_success_dialog.dart';

class BookingCancellationDialog extends StatelessWidget {
  const BookingCancellationDialog({
    required this.message,
    this.requestRefund = false,
    super.key,
  });
  final String message;
  final bool requestRefund;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: CinemaPanel(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                requestRefund
                    ? Icons.currency_exchange_outlined
                    : Icons.cancel_outlined,
                size: 64,
                color: requestRefund ? AppColors.primary : AppColors.error,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                requestRefund ? 'Request refund?' : 'Cancel booking?',
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: requestRefund ? 'Back' : 'Keep',
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton.danger(
                      label: requestRefund ? 'Request' : 'Cancel',
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showBookingCancellationNotice(
  BuildContext context, {
  required String message,
  bool refundRequested = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: refundRequested ? 'Refund requested' : 'Booking cancelled',
  barrierColor: Colors.black.withValues(alpha: 0.72),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => Material(
    type: MaterialType.transparency,
    child: AuthSuccessDialog(
      title: refundRequested ? 'Refund requested' : 'Booking cancelled',
      message: message,
      footer: refundRequested
          ? 'Awaiting staff review'
          : 'Cancellation completed',
      isCancellation: !refundRequested,
    ),
  ),
  transitionBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);
