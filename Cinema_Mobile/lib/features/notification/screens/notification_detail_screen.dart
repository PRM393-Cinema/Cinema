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
import '../../../core/session/session_state.dart';

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
    _notification = _loadAndMarkRead();
  }

  // Opening a notification marks it read (and lowers the badge).
  Future<AppNotification> _loadAndMarkRead() async {
    final notification = await widget.bookingRepository.getNotification(
      widget.notificationId,
    );
    if (notification.isRead) return notification;
    try {
      final read = await widget.bookingRepository.markNotificationRead(
        notification.id,
      );
      if (mounted) {
        final session = SessionProvider.of(context);
        session.setUnreadNotifications(session.unreadNotifications - 1);
      }
      return read;
    } on Object {
      return notification;
    }
  }

  void _retry() => setState(() {
    _notification = widget.bookingRepository.getNotification(
      widget.notificationId,
    );
  });

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Notification',
    width: PageWidth.reading,
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
        return SingleChildScrollView(
          padding: widthPadding(context, AppSpacing.xl, PageWidth.reading),
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
                Text(notification.subject, style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  formatDateTime(notification.createdAt),
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.xl),
                SelectableText(
                  notification.plainContent,
                  style: AppTextStyles.body,
                ),
                if (notification.bookingId != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.secondary(
                    label: 'View booking',
                    leadingIcon: Icons.confirmation_number_outlined,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookingDetail(notification.bookingId!),
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
