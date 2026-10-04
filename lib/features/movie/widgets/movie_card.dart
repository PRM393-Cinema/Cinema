import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_network_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    required this.title,
    this.posterUrl,
    this.genre,
    this.duration,
    this.onTap,
    super.key,
  });

  final String title;
  final String? posterUrl;
  final String? genre;
  final String? duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderRadiusMd,
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.borderRadiusMd,
                child: AppNetworkImage(
                  imageUrl: posterUrl ?? '',
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (genre != null || duration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [if (genre != null) genre, if (duration != null) duration].join(' • '),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
