import 'dart:async';

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
import '../../../data/storage/notification_seen_storage.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({required this.bookingRepository, super.key});

  final BookingRepository bookingRepository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen>
    with WidgetsBindingObserver {
  List<AppNotification> _notifications = const [];
  bool _hasStarted = false;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _loadNotifications(background: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _loadNotifications(background: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStarted) {
      _hasStarted = true;
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications({bool background = false}) async {
    if (_isRefreshing) return;
    final userId = SessionProvider.of(context).user?.userId;
    if (userId == null) {
      _showError('Please sign in to see your notifications.');
      return;
    }

    setState(() {
      _isRefreshing = true;
      _isLoading = !background && _notifications.isEmpty;
      if (!background) _errorMessage = null;
    });

    try {
      final notifications = await widget.bookingRepository.getMyNotifications(
        userId,
      );
      if (!mounted || SessionProvider.of(context).user?.userId != userId) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final latestId = notifications.fold<int>(
        0,
        (latest, item) => item.id > latest ? item.id : latest,
      );
      try {
        await NotificationSeenStorage().markSeen(userId, latestId);
      } on Object {
        // Viewing the list still works if local storage is unavailable.
      }
    } on ApiException catch (error) {
      if (!background) _showError(error.message);
    } on FormatException {
      if (!background) _showError('The server returned an invalid response.');
    } on Object {
      if (!background) _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) _isRefreshing = false;
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
    return CinemaPage(title: 'Notifications', child: _buildBody());
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
          surfaceOpacity: 0.8,
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
