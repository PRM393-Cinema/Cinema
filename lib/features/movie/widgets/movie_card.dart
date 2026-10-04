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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.borderRadiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppNetworkImage(
                imageUrl: posterUrl ?? '',
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl * 1.5,
                borderRadius: AppRadius.borderRadiusSm,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (genre != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        genre!,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (duration != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        duration!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
