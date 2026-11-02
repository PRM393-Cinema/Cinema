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
import '../widgets/notification_category.dart';

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
            padding: EdgeInsets.all(
              isDesktopLayout(context) ? AppSpacing.xxl : AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NotificationCategory(notification: notification),
                    Text(
                      formatDateTime(notification.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppPalette.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.heading1.copyWith(height: 1.3),
                  ),
                ),
                if (bookingCode != null || title != notification.subject) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    bookingCode != null ? 'Booking reference' : 'Subject',
                    style: AppTextStyles.caption.copyWith(
                      color: AppPalette.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    bookingCode ?? notification.subject,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(
                    height: 1,
                    color: AppPalette.of(context).border,
                  ),
                ),
                Semantics(
                  header: true,
                  child: const Text('Message', style: AppTextStyles.title),
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _NotificationBody(content: notification.bodyContent),
                ),
                if (notification.bookingId != null) ...[
                  Divider(
                    height: AppSpacing.xxl,
                    color: AppPalette.of(context).border,
                  ),
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
          (part) => part.contains(RegExp(r'<[^>]+>'))
              ? part.replaceAll(RegExp(r'\s+'), ' ')
              : part,
        )
        .where((part) => htmlToPlainText(part).isNotEmpty);
    // shortcut: groups current email labels; use structured fields if templates change.
    final fieldPattern = RegExp(
      r'^(Phim|Suất chiếu|Ghế|Bắp nước|Giảm giá|Dùng điểm|Điểm thưởng|Tổng tiền|Số tiền|Số tiền hoàn|Lý do|Mã hoàn tiền|Mã giao dịch chuyển khoản|Mã giao dịch|Phương thức thanh toán|Mã đặt vé|Rạp|Phòng):\s*(.+)$',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final source in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Builder(
              builder: (context) {
                final paragraph = htmlToPlainText(source);
                final fields = paragraph
                    .split('\n')
                    .map(fieldPattern.firstMatch)
                    .toList();
                if (fields.any((field) => field == null)) {
                  return _paragraph(source, paragraph);
                }
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppPalette.of(context).surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.of(context).border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        if (index > 0) const SizedBox(height: AppSpacing.lg),
                        Text(
                          fields[index]!.group(1)!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppPalette.of(context).textSecondary,
                          ),
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
                                  color: AppPalette.of(context).primary,
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

  Widget _paragraph(String source, String text) {
    final values =
        RegExp(
              r'<(?:strong|b)\b[^>]*>([\s\S]*?)</(?:strong|b)\s*>',
              caseSensitive: false,
            )
            .allMatches(source)
            .map((match) => htmlToPlainText(match.group(1)!))
            .where((value) => value.isNotEmpty)
            .toSet();
    final spans = <TextSpan>[];
    var offset = 0;
    if (values.isNotEmpty) {
      final emphasis = RegExp(values.map(RegExp.escape).join('|'));
      for (final match in emphasis.allMatches(text)) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
        spans.add(
          TextSpan(
            text: match.group(0),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
        offset = match.end;
      }
    }
    spans.add(TextSpan(text: text.substring(offset)));
    return SelectableText.rich(
      TextSpan(children: spans),
      style: AppTextStyles.body.copyWith(height: 1.65),
    );
  }
}
