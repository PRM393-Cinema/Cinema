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
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';

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
      SessionProvider.of(context)
          .setUnreadNotifications(notifications.where((n) => !n.isRead).length);
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('The server returned an invalid response.');
    } on Object {
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.bookingRepository.markAllNotificationsRead();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _notifications = [
          for (final notification in _notifications)
            notification.markedRead(now),
        ];
      });
      SessionProvider.of(context).setUnreadNotifications(0);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = 'Could not mark them as read.');
      }
    }
  }

  Future<void> _open(AppNotification notification) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.notificationDetail(notification.id),
    );
    // The detail page marks it read.
    if (!mounted || notification.isRead) return;
    setState(() {
      _notifications = [
        for (final item in _notifications)
          item.id == notification.id ? item.markedRead(DateTime.now()) : item,
      ];
    });
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
    return CinemaPage(
      title: 'Notifications',
      width: PageWidth.reading,
      child: _buildBody(),
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
          padding: widthPadding(context, AppSpacing.xl, PageWidth.reading),
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            CinemaPanel(
              surfaceOpacity: 0.8,
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

    final unread = _notifications.where((n) => !n.isRead).length;
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widthPadding(context, AppSpacing.md, PageWidth.reading),
        itemCount: _notifications.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cinema updates', style: AppTextStyles.heading2),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          formatCount(_notifications.length, 'notification'),
                          if (unread > 0) '$unread unread',
                        ].join(' · '),
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                    if (unread > 0)
                      TextButton(
                        key: const Key('markAllRead'),
                        onPressed: _markAllRead,
                        child: const Text('Mark all read'),
                      ),
                  ],
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
            onTap: () => _open(notification),
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
          surfaceOpacity: 0.8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.type == 'SHOWTIME_REMINDER'
                    ? Icons.alarm_rounded
                    : notification.type.startsWith('REFUND')
                    ? Icons.receipt_long_outlined
                    : Icons.confirmation_number_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!notification.isRead) ...[
                          Container(
                            key: ValueKey('unread-${notification.id}'),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            notification.subject,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.plainContent,
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatDateTime(notification.createdAt),
                      style: AppTextStyles.bodySmall,
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
