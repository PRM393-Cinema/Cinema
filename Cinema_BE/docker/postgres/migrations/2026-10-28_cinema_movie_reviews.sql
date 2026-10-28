\set ON_ERROR_STOP on
\connect cinema_booking_db

BEGIN;
CREATE TABLE IF NOT EXISTS movie_reviews (
    id            BIGSERIAL     PRIMARY KEY,
    movie_id      BIGINT        NOT NULL,
    user_id       BIGINT        NOT NULL,
    booking_id    BIGINT        NOT NULL,
    reviewer_name VARCHAR(150)  NOT NULL,
    rating        SMALLINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       VARCHAR(1000),
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT movie_reviews_user_movie_key UNIQUE (user_id, movie_id)
);
CREATE INDEX IF NOT EXISTS idx_movie_reviews_movie ON movie_reviews(movie_id, created_at);
COMMIT;
