\set ON_ERROR_STOP on
\connect cinema_movie_db
UPDATE movies SET preview_url = '/previews/oppenheimer.mp4'
WHERE title = 'Oppenheimer' AND preview_url IS NULL;
UPDATE movies SET preview_url = '/previews/interstellar.mp4'
WHERE title = 'Interstellar' AND preview_url IS NULL;
