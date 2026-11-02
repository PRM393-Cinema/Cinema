import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/app_notification.dart';

class NotificationCategory extends StatelessWidget {
  const NotificationCategory({required this.notification, super.key});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
    decoration: BoxDecoration(
      color: AppPalette.of(context).primary.withValues(alpha: 0.10),
      borderRadius: AppRadius.borderRadiusSm,
    ),
    child: Text(
      notification.categoryLabel,
      style: AppTextStyles.caption.copyWith(
        color: AppPalette.of(context).primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
