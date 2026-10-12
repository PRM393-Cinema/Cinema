import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/showtime.dart';
import 'showtime_chip.dart';

// Showtimes grouped by day ("Today · Tue, Oct 6"), each day a grid of time
// chips. Expects showtimes sorted by start time.
class ShowtimeSection extends StatelessWidget {
  const ShowtimeSection({
    required this.showtimes,
    required this.selectedShowtimeId,
    required this.onSelected,
    super.key,
  });

  final List<Showtime> showtimes;
  final int? selectedShowtimeId;
  final ValueChanged<Showtime> onSelected;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<Showtime>>{};
    for (final showtime in showtimes) {
      days
          .putIfAbsent(DateUtils.dateOnly(showtime.startTime), () => [])
          .add(showtime);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in days.entries) ...[
          Text(
            formatDayHeading(entry.key),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final showtime in entry.value)
                  SizedBox(
                    width: constraints.maxWidth >= 300
                        ? (constraints.maxWidth - AppSpacing.md * 2) / 3
                        : (constraints.maxWidth - AppSpacing.md) / 2,
                    child: ShowtimeChip(
                      time: formatTime(showtime.startTime),
                      room: showtime.roomLabel,
                      price: formatVnd(showtime.price),
                      isSelected: showtime.id == selectedShowtimeId,
                      isAvailable: showtime.isOpen,
                      onTap: () => onSelected(showtime),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
