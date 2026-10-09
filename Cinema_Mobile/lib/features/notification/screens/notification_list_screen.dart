import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/booking_repository.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<AppNotification> _notifications = const [];
  bool _hasStarted = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    if (_isRefreshing) return;
    final userId = SessionProvider.of(context).user?.userId;
    if (userId == null) {
      _showError('Please sign in to see your notifications.');
      return;
    }

    setState(() {
      _isRefreshing = true;
      _isLoading = _notifications.isEmpty;
      _errorMessage = null;
    });

    try {
      final notifications = await widget.bookingRepository.getMyNotifications(
        userId,
      );
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _isRefreshing = false;
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
      _isRefreshing = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Notifications'),
      ),
      body: CinemaBackground(child: SafeArea(child: _buildBody())),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState(message: 'Loading notifications...');
    }

    if (_errorMessage != null && _notifications.isEmpty) {
      return ErrorState(
        title: 'Unable to load notifications',
        message: _errorMessage!,
        onRetry: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: centeredPadding(context, AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            CinemaPanel(
              child: EmptyState(
                icon: Icons.notifications_none_outlined,
                title: 'You’re all caught up',
                message: 'Booking confirmations, cancellations and refund updates will appear here.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centeredPadding(context, AppSpacing.md),
        itemCount: _notifications.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your cinema updates', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_notifications.length} notifications',
                  style: AppTextStyles.caption,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            );
          }
          final notification = _notifications[index - 1];
          return _NotificationTile(
            notification: notification,
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.notificationDetail(notification.id),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMd,
        child: CinemaPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.type.startsWith('REFUND')
                    ? Icons.receipt_long_outlined
                    : Icons.confirmation_number_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.subject,
                      style: AppTextStyles.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.plainContent,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatDateTime(notification.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
