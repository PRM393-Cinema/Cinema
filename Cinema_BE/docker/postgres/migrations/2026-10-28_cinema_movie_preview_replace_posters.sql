\set ON_ERROR_STOP on
\connect cinema_movie_db
BEGIN;
UPDATE movies SET preview_url = '/previews/movie-1-trailer.mp4' WHERE preview_url = '/previews/movie-1-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-2-trailer.mp4' WHERE preview_url = '/previews/movie-2-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-3-trailer.mp4' WHERE preview_url = '/previews/movie-3-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-4-trailer.mp4' WHERE preview_url = '/previews/movie-4-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-5-trailer.mp4' WHERE preview_url = '/previews/movie-5-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-6-trailer.mp4' WHERE preview_url = '/previews/movie-6-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-7-trailer.mp4' WHERE preview_url = '/previews/movie-7-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-10-trailer.mp4' WHERE preview_url = '/previews/movie-10-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-11-trailer.mp4' WHERE preview_url = '/previews/movie-11-intro.mp4';
UPDATE movies SET preview_url = '/previews/movie-13-trailer.mp4' WHERE preview_url = '/previews/movie-13-intro.mp4';
COMMIT;
