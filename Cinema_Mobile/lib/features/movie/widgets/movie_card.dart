import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../core/widgets/app_network_image.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({
    required this.title,
    this.posterUrl,
    this.genre,
    this.duration,
    this.ageRating,
    this.badge,
    this.onTap,
    this.onPreview,
    super.key,
  });

  final String title;
  final String? posterUrl;
  final String? genre;
  final String? duration;
  final AgeRating? ageRating;

  // A note on the poster, e.g. the release date of a movie coming soon.
  final String? badge;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;

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
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.borderRadiusMd,
                    child: AppNetworkImage(
                      imageUrl: posterUrl ?? '',
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  if (ageRating case final rating?)
                    Positioned(
                      top: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: AgeRatingBadge(rating: rating),
                    ),
                  if (badge case final text?)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: AppRadius.borderRadiusSm,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          child: Text(
                            text,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.background,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onPreview != null)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: IconButton.filledTonal(
                        tooltip: 'Preview $title',
                        onPressed: onPreview,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: AppColors.background.withValues(
                            alpha: 0.85,
                          ),
                          foregroundColor: AppColors.textPrimary,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ),
                ],
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
              [
                if (genre != null) genre,
                if (duration != null) duration,
              ].join(' • '),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
