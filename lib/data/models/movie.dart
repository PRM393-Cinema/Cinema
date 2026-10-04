class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.genre,
    required this.language,
    required this.releaseDate,
    required this.posterUrl,
    required this.trailerUrl,
    required this.status,
  });

  final String id;
  final String title;
  final String description;
  final int durationMinutes;
  final String genre;
  final String language;
  final DateTime releaseDate;
  final String posterUrl;
  final String trailerUrl;
  final String status; // 'ACTIVE', 'INACTIVE'

  String get durationText => '$durationMinutes min';
  String get releaseYear => releaseDate.year.toString();
}
