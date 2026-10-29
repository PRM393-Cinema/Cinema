import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/loyalty.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/membership_card.dart';

class PointHistoryScreen extends StatefulWidget {
  const PointHistoryScreen({required this.bookingRepository, super.key});
  final BookingRepository bookingRepository;
  @override
  State<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends State<PointHistoryScreen> {
  late Future<LoyaltyCard> _card;
  @override
  void initState() {
    super.initState();
    _card = widget.bookingRepository.getMyLoyalty();
  }

  Future<void> _reload() async {
    final request = widget.bookingRepository.getMyLoyalty();
    setState(() {
      _card = request;
    });
    try {
      await request;
    } on Object {
      /* Rendered by FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Point history',
    width: PageWidth.reading,
    child: FutureBuilder<LoyaltyCard>(
      future: _card,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(message: 'Loading points...');
        }
        if (snapshot.hasError) {
          return ErrorState(
            title: 'Unable to load point history',
            message: 'Please try again.',
            onRetry: _reload,
          );
        }
        final card = snapshot.data!;
        final history = [...card.history]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widthPadding(context, AppSpacing.lg, PageWidth.reading)
                .copyWith(
                  bottom:
                      AppSpacing.lg +
                      (isDesktopLayout(context) ? 0 : 96) +
                      MediaQuery.paddingOf(context).bottom,
                ),
            itemCount: history.isEmpty ? 2 : history.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return CinemaPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available points',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${card.points} points',
                        style: AppTextStyles.heading1.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Latest 50 transactions · Newest first',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                );
              }
              if (history.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No point activity yet',
                  message: 'Points earned, used and returned will appear here.',
                );
              }
              final line = history[index - 1];
              return CinemaPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PointsLine(line: line),
                    if (line.bookingId != null)
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.bookingDetail(line.bookingId!),
                        ),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('View booking'),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
