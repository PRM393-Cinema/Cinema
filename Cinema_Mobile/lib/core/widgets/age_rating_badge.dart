import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

// Film classification, shown wherever a movie is advertised (Vietnam's Cinema
// Law 2022 and Circular 05/2023/TT-BVHTTDL).
enum AgeRating {
  p('P', 'All ages', AppColors.success),
  k('K', 'Under 13 only with a parent or guardian', Color(0xFF3B82F6)),
  t13('T13', '13 and over', Color(0xFFEAB308)),
  t16('T16', '16 and over', AppColors.accent),
  t18('T18', '18 and over', AppColors.error);

  const AgeRating(this.code, this.meaning, this.color);

  final String code;
  final String meaning;
  final Color color;

  static AgeRating parse(String? code) => values.firstWhere(
    (rating) => rating.code == code?.trim().toUpperCase(),
    orElse: () => p,
  );

  // Anything but P asks the viewer to mind their age (or a child's).
  bool get restricted => this != p;
}

class AgeRatingBadge extends StatelessWidget {
  const AgeRatingBadge({required this.rating, this.large = false, super.key});

  final AgeRating rating;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${rating.code}: ${rating.meaning}',
      child: Container(
        key: ValueKey('ageRating-${rating.code}'),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 6,
          vertical: large ? 4 : 2,
        ),
        decoration: BoxDecoration(
          color: rating.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          rating.code,
          style: (large ? AppTextStyles.title : AppTextStyles.caption).copyWith(
            color: rating == AgeRating.t13 ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
