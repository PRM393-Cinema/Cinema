import 'movie.dart';
import '../../core/widgets/age_rating_badge.dart';

// Fields an admin fills in to add or edit a movie (MovieRequest on the API).
class MovieDraft {
  const MovieDraft({
    required this.title,
    required this.durationMinutes,
    required this.releaseDate,
    this.description = '',
    this.genre = '',
    this.language = '',
    this.posterUrl = '',
    this.trailerUrl = '',
    this.ageRating = AgeRating.p,
  });

  factory MovieDraft.fromMovie(Movie movie) => MovieDraft(
    title: movie.title,
    durationMinutes: movie.durationMinutes,
    releaseDate: movie.releaseDate ?? DateTime.now(),
    description: movie.description,
    genre: movie.genre,
    language: movie.language,
    posterUrl: movie.posterUrl,
    trailerUrl: movie.trailerUrl,
    ageRating: movie.ageRating,
  );

  final String title;
  final int durationMinutes;
  final DateTime releaseDate;
  final String description;
  final String genre;
  final String language;
  final String posterUrl;
  final String trailerUrl;
  final AgeRating ageRating;

  Map<String, Object?> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'durationMinutes': durationMinutes,
    'genre': genre.trim(),
    'language': language.trim(),
    // The API keeps the date only.
    'releaseDate': DateTime(
      releaseDate.year,
      releaseDate.month,
      releaseDate.day,
    ).toIso8601String(),
    'posterUrl': posterUrl.trim(),
    'trailerUrl': trailerUrl.trim(),
    'ageRating': ageRating.code,
  };
}
