import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/utils/html_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_account_widgets.dart';

import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../core/session/session_state.dart';
import '../../review/widgets/review_widgets.dart';

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
    _notification = _loadAndMarkRead();
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
        final title = notification.displayTitle;
        final bookingCode = notification.bookingCode;
        return SingleChildScrollView(
          padding: widthPadding(context, AppSpacing.xl, PageWidth.reading),
          child: CinemaPanel(
            surfaceOpacity: 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        formatDateTime(notification.createdAt),
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTextStyles.heading2),
                if (bookingCode != null || title != notification.subject) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    bookingCode ?? notification.subject,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                _NotificationBody(content: notification.bodyContent),
                if (notification.bookingId != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      AppButton.secondary(
                        key: const Key('viewBooking'),
                        label: 'View booking',
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.bookingDetail(notification.bookingId!),
                        ),
                      ),
                      TicketReviewButton(
                        bookingId: notification.bookingId!,
                        repository: widget.bookingRepository,
                      ),
                    ],
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
    // Keep email paragraphs and explicit line breaks, ignoring source indentation.
    final paragraphs = content
        .split(RegExp(r'</p\s*>', caseSensitive: false))
        .map(
          (part) => htmlToPlainText(
            part.contains(RegExp(r'<[^>]+>'))
                ? part.replaceAll(RegExp(r'\s+'), ' ')
                : part,
          ),
        )
        .where((part) => part.isNotEmpty);
    // shortcut: groups current email labels; use structured fields if templates change.
    final fieldPattern = RegExp(
      r'^(Phim|Suất chiếu|Ghế|Bắp nước|Giảm giá|Dùng điểm|Điểm thưởng|Tổng tiền|Số tiền|Số tiền hoàn|Lý do|Mã hoàn tiền|Mã giao dịch chuyển khoản|Mã giao dịch|Phương thức thanh toán|Mã đặt vé|Rạp|Phòng):\s*(.+)$',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Builder(
              builder: (context) {
                final fields = paragraph
                    .split('\n')
                    .map(fieldPattern.firstMatch)
                    .toList();
                if (fields.any((field) => field == null)) {
                  return SelectableText(
                    paragraph,
                    style: AppTextStyles.body.copyWith(height: 1.5),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.lg),
                        Text(
                          fields[index]!.group(1)!,
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          fields[index]!.group(2)!,
                          style:
                              const [
                                'Tổng tiền',
                                'Số tiền',
                                'Số tiền hoàn',
                              ].contains(fields[index]!.group(1))
                              ? AppTextStyles.heading2.copyWith(
                                  color: AppColors.primary,
                                )
                              : AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
