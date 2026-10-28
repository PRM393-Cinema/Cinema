import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/session/session_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/booking.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/booking_repository.dart';

// Stars for a rating of 0 to 5 (halves round to the nearest whole star).
class StarRating extends StatelessWidget {
  const StarRating({required this.rating, this.size = 18, super.key});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            star <= full ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: AppColors.warning,
          ),
      ],
    );
  }
}

// Tap a star to rate 1 to 5.
class StarPicker extends StatelessWidget {
  const StarPicker({required this.value, required this.onChanged, super.key});

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            key: ValueKey('star-$star'),
            tooltip: '$star star${star == 1 ? '' : 's'}',
            onPressed: onChanged == null ? null : () => onChanged!(star),
            icon: Icon(
              star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 34,
              color: AppColors.warning,
            ),
          ),
      ],
    );
  }
}

// Ratings on the movie page: the average, how many gave each star and the
// newest reviews.
class MovieReviewsSection extends StatefulWidget {
  const MovieReviewsSection({
    required this.load,
    required this.movie,
    required this.repository,
    super.key,
  });

  final Future<MovieReviews> Function() load;
  final Movie movie;
  final BookingRepository repository;

  @override
  State<MovieReviewsSection> createState() => _MovieReviewsSectionState();
}

class _MovieReviewsSectionState extends State<MovieReviewsSection> {
  MovieReviews? _reviews;
  bool _failed = false;
  bool _writing = false;
  String? _writeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reviews = await widget.load();
      if (mounted) setState(() => _reviews = reviews);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _rate() async {
    final session = SessionProvider.of(context);
    if (!session.isAuthenticated) {
      await Navigator.pushNamed(
        context,
        AppRoutes.login,
        arguments: {'pendingRoute': AppRoutes.movieDetail(widget.movie.id)},
      );
      if (mounted) await _load();
      return;
    }
    setState(() {
      _writing = true;
      _writeError = null;
    });
    try {
      final bookings = await widget.repository.getMyBookings(
        session.user!.userId,
      );
      for (final booking in bookings.where((b) => b.checkedInAt != null)) {
        final state = await widget.repository.getBookingReview(booking.id);
        if (!mounted) return;
        if (state.movieId != widget.movie.id || !state.canReview) continue;
        setState(() => _writing = false);
        final result = await showDialog<(int, String)>(
          context: context,
          builder: (_) => _ReviewDialog(
            movieTitle: widget.movie.title,
            rating: state.review?.rating ?? 0,
            comment: state.review?.comment ?? '',
          ),
        );
        if (result == null || !mounted) return;
        setState(() => _writing = true);
        await widget.repository.saveReview(
          bookingId: booking.id,
          rating: result.$1,
          comment: result.$2,
        );
        await _load();
        return;
      }
      if (mounted) {
        setState(
          () => _writeError = 'You can rate this movie after your ticket has been checked in at the cinema.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _writeError = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _writeError = 'Unable to save your review. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    return Column(
      key: const Key('movieReviews'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ratings & reviews', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          key: const Key('rateMovie'),
          label: SessionProvider.of(context).isAuthenticated
              ? 'Rate this movie'
              : 'Sign in to rate this movie',
          leadingIcon: Icons.star_outline_rounded,
          isLoading: _writing,
          onPressed: _writing ? null : _rate,
        ),
        if (_writeError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_writeError!, style: AppTextStyles.bodySmall),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (reviews == null)
          Text(
            _failed ? 'Reviews could not be loaded.' : 'Loading reviews...',
            style: AppTextStyles.bodySmall,
          )
        else if (reviews.count == 0)
          const Text(
            'No reviews yet. Customers can rate a movie after watching it.',
            style: AppTextStyles.bodySmall,
          )
        else ...[
          _Summary(reviews: reviews),
          const SizedBox(height: AppSpacing.lg),
          for (final review in reviews.reviews.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ReviewTile(review: review),
            ),
          if (reviews.count > reviews.reviews.items.length)
            Text(
              'Showing the ${reviews.reviews.items.length} newest of '
              '${reviews.count} reviews.',
              style: AppTextStyles.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.reviews});

  final MovieReviews reviews;

  @override
  Widget build(BuildContext context) {
    final most = reviews.stars.fold(
      0,
      (max, count) => count > max ? count : max,
    );
    return CinemaPanel(
      surfaceOpacity: 0.8,
      child: Row(
        children: [
          Column(
            children: [
              Text(
                reviews.average.toStringAsFixed(1),
                key: const Key('reviewAverage'),
                style: AppTextStyles.display.copyWith(color: AppColors.warning),
              ),
              StarRating(rating: reviews.average),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatCount(reviews.count, 'review'),
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$star', style: AppTextStyles.bodySmall),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: most == 0
                                  ? 0
                                  : reviews.stars[star - 1] / most,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceSoft,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({required this.review, this.trailing, super.key});

  final MovieReview review;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('review-${review.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                review.mine
                    ? '${review.reviewerName} (you)'
                    : review.reviewerName,
                style: AppTextStyles.title,
              ),
            ),
            StarRating(rating: review.rating.toDouble(), size: 16),
            ?trailing,
          ],
        ),
        Text(
          '${formatDate(review.updatedAt)}${review.edited ? ' · edited' : ''}',
          style: AppTextStyles.bodySmall,
        ),
        if (review.comment case final comment?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(comment, style: AppTextStyles.body),
        ],
      ],
    );
  }
}

// The rating of a ticket's movie on the ticket page: allowed once the ticket
// was checked in; one review per movie, which can be changed or removed.
class TicketReviewCard extends StatefulWidget {
  const TicketReviewCard({
    required this.booking,
    required this.repository,
    super.key,
  });

  final Booking booking;
  final BookingRepository repository;

  @override
  State<TicketReviewCard> createState() => _TicketReviewCardState();
}

class _TicketReviewCardState extends State<TicketReviewCard> {
  BookingReview? _state;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await widget.repository.getBookingReview(widget.booking.id);
      if (mounted) setState(() => _state = state);
    } on Object {
      // The ticket page works without the review card.
    }
  }

  Future<void> _write() async {
    final current = _state?.review;
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _ReviewDialog(
        movieTitle: widget.booking.movieTitle ?? 'this movie',
        rating: current?.rating ?? 0,
        comment: current?.comment ?? '',
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final review = await widget.repository.saveReview(
        bookingId: widget.booking.id,
        rating: result.$1,
        comment: result.$2,
      );
      if (mounted) {
        setState(() {
          _state = BookingReview(
            bookingId: widget.booking.id,
            movieId: review.movieId,
            canReview: true,
            review: review,
          );
        });
      }
    });
  }

  Future<void> _delete(MovieReview review) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete your review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const Key('confirmDeleteReview'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _run(() async {
      await widget.repository.deleteReview(review.id);
      if (mounted) {
        setState(() {
          _state = BookingReview(
            bookingId: widget.booking.id,
            movieId: review.movieId,
            canReview: true,
          );
        });
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    final review = state.review;
    return CinemaPanel(
      key: const Key('ticketReview'),
      surfaceOpacity: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your review', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          if (!state.canReview)
            const Text(
              'You can rate this movie after watching it, once your ticket '
              'is checked in at the cinema.',
              style: AppTextStyles.bodySmall,
            )
          else if (review == null) ...[
            const Text(
              'How was the movie? Your rating helps other customers.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              key: const Key('writeReview'),
              label: 'Write a review',
              leadingIcon: Icons.star_outline_rounded,
              isLoading: _busy,
              onPressed: _busy ? null : _write,
            ),
          ] else ...[
            ReviewTile(review: review),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    key: const Key('editReview'),
                    label: 'Edit',
                    onPressed: _busy ? null : _write,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.danger(
                    key: const Key('deleteReview'),
                    label: 'Delete',
                    isLoading: _busy,
                    onPressed: _busy ? null : () => _delete(review),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

// Stars and an optional comment; returns (rating, comment).
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.movieTitle,
    required this.rating,
    required this.comment,
  });

  final String movieTitle;
  final int rating;
  final String comment;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late int _rating = widget.rating;
  late final _comment = TextEditingController(text: widget.comment);
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _save() {
    if (_rating < 1) {
      setState(() => _error = 'Choose 1 to 5 stars.');
      return;
    }
    if (_comment.text.trim().length > 1000) {
      setState(() => _error = 'Use at most 1000 characters.');
      return;
    }
    Navigator.pop(context, (_rating, _comment.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Rate ${widget.movieTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StarPicker(
              value: _rating,
              onChanged: (value) => setState(() {
                _rating = value;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: const Key('reviewCommentField'),
              label: 'Comment (optional)',
              controller: _comment,
              maxLines: 4,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('saveReview'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
