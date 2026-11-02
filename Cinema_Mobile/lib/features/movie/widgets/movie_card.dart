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

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
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
                  color: colors.border.withValues(
                    alpha: colors.isLight ? 1 : 0.5,
                  ),
                ),
                boxShadow: colors.isLight
                    ? [
                        BoxShadow(
                          color: colors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
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
                          color: AppPalette.of(context).accent,
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
                              color: AppPalette.of(context).background,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
                color: AppPalette.of(context).textSecondary,
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
