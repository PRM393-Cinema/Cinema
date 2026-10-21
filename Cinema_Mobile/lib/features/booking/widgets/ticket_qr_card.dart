import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking.dart';

// The ticket of a paid booking: staff scan its QR code (the booking code) at
// the cinema to check the customer in. A used ticket says when.
class TicketQrCard extends StatelessWidget {
  const TicketQrCard({required this.booking, super.key});

  static const qrSize = 200.0;

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final checkedInAt = booking.checkedInAt;

    return CinemaPanel(
      key: const Key('ticketQr'),
      surfaceOpacity: 0.8,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Your ticket', style: AppTextStyles.title)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Dark modules on white: scanners read it at any screen brightness.
          Opacity(
            opacity: checkedInAt == null ? 1 : 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: QrImageView(
                  data: booking.bookingCode,
                  size: qrSize,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Ticket QR code ${booking.bookingCode}',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            booking.bookingCode,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (checkedInAt == null)
            Text(
              'Show this QR code at the cinema to check in.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    'Checked in ${formatDateTime(checkedInAt)}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
