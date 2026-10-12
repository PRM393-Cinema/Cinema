import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/booking_repository.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    required this.bookingRepository,
    required this.notificationId,
    super.key,
  });

  final BookingRepository bookingRepository;
  final int notificationId;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late Future<AppNotification> _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.bookingRepository.getNotification(
      widget.notificationId,
    );
  }

  void _retry() => setState(() {
    _notification = widget.bookingRepository.getNotification(
      widget.notificationId,
    );
  });

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Notification',
    child: FutureBuilder<AppNotification>(
      future: _notification,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(message: 'Loading notification...');
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return ErrorState(
            title: 'Unable to load notification',
            message: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            onRetry: _retry,
          );
        }
        final notification = snapshot.data!;
        final bookingCode = RegExp(r'\bBK-\d+-\d+\b')
            .firstMatch(notification.subject)
            ?.group(0);
        final title = bookingCode == null
            ? notification.subject
            : notification.subject.replaceFirst(bookingCode, '').trim();
        return SingleChildScrollView(
          padding: centeredPadding(context, AppSpacing.xl),
          child: CinemaPanel(
            surfaceOpacity: 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTextStyles.heading2),
                if (bookingCode != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    bookingCode,
                    style: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  formatDateTime(notification.createdAt),
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.xl),
                _NotificationBody(content: notification.plainContent),
                if (notification.bookingId != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'View booking',
                      useGradient: true,
                      leadingIcon: Icons.confirmation_number_outlined,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.bookingDetail(notification.bookingId!),
                      ),
                    ),
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

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, line) in lines.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == lines.length - 1 ? 0 : AppSpacing.md,
            ),
            child: _line(line, index),
          ),
      ],
    );
  }

  Widget _line(String line, int index) {
    final separator = line.indexOf(':');
    final label = separator < 0 ? '' : line.substring(0, separator).trim();
    final value = separator < 0 ? '' : line.substring(separator + 1).trim();
    final icon = switch (label) {
      'Phim' => Icons.movie_outlined,
      'Suất chiếu' => Icons.schedule_rounded,
      'Ghế' => Icons.event_seat_outlined,
      'Tổng tiền' => Icons.payments_outlined,
      _ => null,
    };
    if (icon != null && value.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 80,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SelectableText(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: label == 'Tổng tiền'
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      );
    }
    if (label == 'ĐẶC BIỆT LƯU Ý' && value.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lưu ý',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              value,
              style: AppTextStyles.bodySmall.copyWith(height: 1.6),
            ),
          ],
        ),
      );
    }
    return SelectableText(
      line,
      style: (index == 0 ? AppTextStyles.title : AppTextStyles.bodySmall)
          .copyWith(height: 1.6),
    );
  }
}
