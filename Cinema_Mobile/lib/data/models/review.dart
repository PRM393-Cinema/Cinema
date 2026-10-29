import 'json_readers.dart';
import 'paged_result.dart';

// A customer's rating of a movie they watched (their ticket was checked in).
class MovieReview {
  const MovieReview({
    required this.id,
    required this.movieId,
    required this.bookingId,
    required this.reviewerName,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.comment,
    this.mine = false,
    this.movieTitle,
  });

  factory MovieReview.fromJson(Map<String, Object?> json) => MovieReview(
    id: readInt(json['id']),
    movieId: readInt(json['movieId']),
    movieTitle: readOptionalString(json['movieTitle']),
    bookingId: readInt(json['bookingId']),
    reviewerName: readString(json['reviewerName'], fallback: 'Customer'),
    rating: readOptionalInt(json['rating']) ?? 0,
    comment: readOptionalString(json['comment']),
    createdAt: readRequiredDateTime(json['createdAt']),
    updatedAt: readRequiredDateTime(json['updatedAt']),
    mine: json['mine'] == true,
  );

  final int id;
  final int movieId;
  final String? movieTitle;
  final int bookingId;
  final String reviewerName;

  // 1 to 5 stars.
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Written by the signed-in customer.
  final bool mine;

  bool get edited => updatedAt.difference(createdAt).inMinutes >= 1;

  String get movieLabel => movieTitle == null || movieTitle!.trim().isEmpty
      ? 'Movie #$movieId'
      : movieTitle!;
}

// The average, the count per star and the newest reviews of a movie.
class MovieReviews {
  const MovieReviews({
    required this.movieId,
    required this.average,
    required this.count,
    required this.stars,
    required this.reviews,
  });

  factory MovieReviews.fromJson(Map<String, Object?> json) => MovieReviews(
    movieId: readInt(json['movieId']),
    average: readDouble(json['average']),
    count: readOptionalInt(json['count']) ?? 0,
    stars: [
      if (json['stars'] case final List values)
        for (final value in values) readInt(value),
    ],
    reviews: PagedResult.fromJson(json['reviews'], MovieReview.fromJson),
  );

  static const empty = MovieReviews(
    movieId: 0,
    average: 0,
    count: 0,
    stars: [0, 0, 0, 0, 0],
    reviews: PagedResult(
      items: [],
      pageNumber: 1,
      totalPages: 0,
      totalCount: 0,
    ),
  );

  final int movieId;
  final double average;
  final int count;

  // How many reviews gave 1..5 stars (index 0 is 1 star).
  final List<int> stars;
  final PagedResult<MovieReview> reviews;
}

// The review of a ticket's movie: allowed once the ticket was checked in.
class BookingReview {
  const BookingReview({
    required this.bookingId,
    required this.movieId,
    required this.canReview,
    this.review,
  });

  factory BookingReview.fromJson(Map<String, Object?> json) => BookingReview(
    bookingId: readInt(json['bookingId']),
    movieId: readInt(json['movieId']),
    canReview: json['canReview'] == true,
    review: json['review'] is Map
        ? MovieReview.fromJson(readMap(json['review']))
        : null,
  );

  final int bookingId;
  final int movieId;
  final bool canReview;
  final MovieReview? review;
}
