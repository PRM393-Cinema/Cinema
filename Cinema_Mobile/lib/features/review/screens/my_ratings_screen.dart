import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/booking_repository.dart';
import '../widgets/review_widgets.dart';

class MyRatingsScreen extends StatefulWidget {
  const MyRatingsScreen({required this.bookingRepository, super.key});
  final BookingRepository bookingRepository;

  @override
  State<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends State<MyRatingsScreen> {
  List<MovieReview> _reviews = [];
  final _movieFilter = TextEditingController();
  int? _stars;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _movieFilter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _reviews.isEmpty;
      _error = null;
    });
    try {
      final reviews = [...await widget.bookingRepository.getMyReviews()];
      reviews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException ? error.message : 'Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      CinemaPage(title: 'My ratings', width: PageWidth.reading, child: _body());

  Widget _body() {
    if (_loading) return const LoadingState(message: 'Loading ratings...');
    if (_error != null) {
      return ErrorState(
        title: 'Unable to load ratings',
        message: _error!,
        onRetry: _load,
      );
    }
    final query = _movieFilter.text.trim().toLowerCase();
    final visible = _reviews
        .where(
          (review) =>
              (_stars == null || review.rating == _stars) &&
              review.movieLabel.toLowerCase().contains(query),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widthPadding(context, AppSpacing.lg, PageWidth.reading),
        itemCount: visible.isEmpty ? 2 : visible.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final search = AppTextField(
                      key: const Key('ratingMovieFilter'),
                      label: 'Search movies',
                      controller: _movieFilter,
                      prefixIcon: const Icon(Icons.search),
                      onChanged: (_) => setState(() {}),
                    );
                    final rating = Theme(
                      data: Theme.of(context).copyWith(
                        focusColor: AppColors.primary.withValues(alpha: 0.10),
                        hoverColor: AppColors.primary.withValues(alpha: 0.06),
                      ),
                      child: PopupMenuButton<int>(
                        key: const Key('ratingStarsFilter'),
                        initialValue: _stars ?? 0,
                        tooltip: 'Filter by rating',
                        position: PopupMenuPosition.under,
                        color: AppColors.surface,
                        surfaceTintColor: Colors.transparent,
                        constraints: const BoxConstraints(
                          minWidth: 220,
                          maxWidth: 280,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderRadiusMd,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        itemBuilder: (_) => [
                          for (final value in [0, 5, 4, 3, 2, 1])
                            PopupMenuItem(
                              value: value,
                              child: Semantics(
                                selected: value == (_stars ?? 0),
                                child: Row(
                                  children: [
                                    Icon(
                                      value == 0
                                          ? Icons.star_border_rounded
                                          : Icons.star_rounded,
                                      size: 20,
                                      color: value == 0
                                          ? AppColors.textSecondary
                                          : AppColors.warning,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(
                                        value == 0
                                            ? 'All ratings'
                                            : formatCount(value, 'star'),
                                        style: AppTextStyles.body.copyWith(
                                          color: value == (_stars ?? 0)
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                          fontWeight: value == (_stars ?? 0)
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    if (value == (_stars ?? 0)) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                        onSelected: (value) =>
                            setState(() => _stars = value == 0 ? null : value),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Star rating',
                            suffixIcon: Icon(Icons.expand_more_rounded),
                          ),
                          child: Text(
                            _stars == null
                                ? (compact ? 'All' : 'All ratings')
                                : formatCount(_stars!, 'star'),
                            style: AppTextStyles.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            semanticsLabel: _stars == null
                                ? 'All ratings'
                                : formatCount(_stars!, 'star'),
                          ),
                        ),
                      ),
                    );
                    if (constraints.maxWidth >= 300 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 24) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: search),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(flex: 2, child: rating),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        const SizedBox(height: AppSpacing.md),
                        rating,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${formatCount(visible.length, 'rating')} · Newest first',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            );
          }
          if (visible.isEmpty) {
            return EmptyState(
              icon: Icons.star_outline_rounded,
              title: _reviews.isEmpty
                  ? 'No ratings yet'
                  : 'No matching ratings',
              message: _reviews.isEmpty
                  ? 'Your movie ratings will appear here after you write a review.'
                  : 'Try another movie name or star rating.',
            );
          }
          final review = visible[index - 1];
          return CinemaPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.movieDetail(review.movieId),
                  ),
                  child: Text(review.movieLabel, style: AppTextStyles.title),
                ),
                const SizedBox(height: AppSpacing.sm),
                ReviewTile(review: review),
              ],
            ),
          );
        },
      ),
    );
  }
}
