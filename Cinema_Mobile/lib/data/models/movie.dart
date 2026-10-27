import '../../core/widgets/age_rating_badge.dart';
import 'json_readers.dart';

import 'package:flutter/material.dart';

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
    this.ageRating = AgeRating.p,
    this.director = '',
    this.cast = '',
  });

  factory Movie.fromJson(Map<String, Object?> json) {
    final releaseDate = readDateTime(json['releaseDate']);

    return Movie(
      id: readInt(json['id']),
      title: readString(json['title'], fallback: 'Untitled movie'),
      description: readString(json['description']),
      durationMinutes: readOptionalInt(json['durationMinutes']) ?? 0,
      genre: readString(json['genre']),
      language: readString(json['language']),
      // DateOnly defaults to 0001-01-01 when the movie has no release date.
      releaseDate: releaseDate != null && releaseDate.year > 1
          ? releaseDate
          : null,
      posterUrl: readString(json['posterUrl']),
      trailerUrl: readString(json['trailerUrl']),
      status: readString(json['status']),
      ageRating: AgeRating.parse(readOptionalString(json['ageRating'])),
      director: readString(json['director']),
      cast: readString(json['cast']),
    );
  }

  final int id;
  final String title;
  final String description;
  final int durationMinutes;
  final String genre;
  final String language;
  final DateTime? releaseDate;
  final String posterUrl;
  final String trailerUrl;
  final String status; // 'ACTIVE', 'INACTIVE'
  final AgeRating ageRating;

  // Main cast, separated by commas.
  final String director;
  final String cast;

  String get durationText => '$durationMinutes min';
  String get releaseYear => releaseDate?.year.toString() ?? '';

  // Not released yet: shown under "Coming soon", usually without showtimes.
  bool isComingSoon([DateTime? now]) {
    final release = releaseDate;
    if (release == null) return false;
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    return DateUtils.dateOnly(release).isAfter(today);
  }
}
