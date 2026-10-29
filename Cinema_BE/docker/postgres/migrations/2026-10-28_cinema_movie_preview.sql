\set ON_ERROR_STOP on
\connect cinema_movie_db
ALTER TABLE movies ADD COLUMN IF NOT EXISTS preview_url VARCHAR(500);
