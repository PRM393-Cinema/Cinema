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
import '../../../core/widgets/paginated_cards.dart';
import '../../../core/widgets/app_text_field.dart';

import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/notification_category.dart';

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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
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
      showHeader: !isDesktopLayout(context),
      width: isDesktopLayout(context) ? PageWidth.page : PageWidth.reading,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final desktop = isDesktopLayout(context);
    final width = desktop ? PageWidth.page : PageWidth.reading;
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
          padding: widthPadding(context, AppSpacing.xl, width),
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
    final query = _search.text.trim().toLowerCase();
    final visible = _notifications
        .where(
          (notification) =>
              '${notification.displayTitle} ${notification.subject} '
                      '${notification.categoryLabel} ${notification.bookingCode ?? ''} '
                      '${notification.plainContent}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widthPadding(context, AppSpacing.md, width),
        itemCount: 2,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) ...[
                  Semantics(
                    header: true,
                    child: const Text(
                      'Notifications',
                      style: AppTextStyles.heading1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Booking confirmations, reminders and refund updates.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppPalette.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                AppTextField(
                  key: const Key('notificationSearch'),
                  label: 'Search notifications',
                  hint: 'Title, message or booking code',
                  controller: _search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('clearNotificationSearch'),
                          tooltip: 'Clear search',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      Text(
                        [
                          query.isEmpty
                              ? formatCount(
                                  _notifications.length,
                                  'notification',
                                )
                              : '${visible.length} of ${formatCount(_notifications.length, 'notification')}',
                          if (unread > 0) '$unread unread',
                        ].join(' · '),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppPalette.of(context).textSecondary,
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
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppPalette.of(context).error,
                    ),
                  ),
                ],
              ],
            );
          }
          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching notifications',
              message: 'Try another title, message or booking code.',
            );
          }
          return PaginatedCards(
            resetKey: query,
            itemCount: visible.length,
            itemBuilder: (_, index) => _NotificationTile(
              notification: visible[index],
              onTap: () => _open(visible[index]),
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
    final desktop = isDesktopLayout(context);
    final scale = MediaQuery.textScalerOf(context);
    final colors = AppPalette.of(context);
    return SizedBox(
      key: ValueKey('notificationCard-${notification.id}'),
      height: desktop ? 300 * scale.scale(1) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderRadiusMd,
          child: CinemaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: NotificationCategory(notification: notification),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!notification.isRead) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Semantics(
                        label: 'Unread',
                        child: Container(
                          key: ValueKey('unread-${notification.id}'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: desktop ? scale.scale(18) * 1.3 * 2 : null,
                  child: Semantics(
                    header: true,
                    child: Text(
                      notification.displayTitle,
                      key: ValueKey('notificationTitle-${notification.id}'),
                      style: AppTextStyles.title.copyWith(
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                      maxLines: desktop ? 2 : null,
                      overflow: desktop ? TextOverflow.ellipsis : null,
                    ),
                  ),
                ),
                if (notification.previewText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    notification.previewText,
                    style: AppTextStyles.bodySmall.copyWith(
                      height: 1.5,
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (desktop) const Spacer(),
                if (notification.bookingCode != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Divider(
                      height: 1,
                      color: AppPalette.of(context).border,
                    ),
                  ),
                  Text(
                    'Booking reference',
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Tooltip(
                    message: notification.bookingCode!,
                    child: Text(
                      notification.bookingCode!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: desktop ? 1 : null,
                      overflow: desktop ? TextOverflow.ellipsis : null,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDateTime(notification.createdAt),
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: desktop ? 1 : null,
                        overflow: desktop ? TextOverflow.ellipsis : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: colors.primary,
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
}
