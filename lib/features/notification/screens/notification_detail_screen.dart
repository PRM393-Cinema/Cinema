import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/app_notification.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! AppNotification) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: const ErrorState(
          title: 'Notification not found',
          message: 'Please return and open the notification again.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(args.subject, style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatDateTime(args.sentAt ?? args.createdAt),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              SelectableText(args.plainContent, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
