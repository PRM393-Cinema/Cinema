\set ON_ERROR_STOP on
\connect cinema_movie_db
BEGIN;
UPDATE movies SET preview_url = '/previews/movie-1-trailer.mp4' WHERE title = 'Chuyến Tàu Sinh Tử' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-2-trailer.mp4' WHERE title = 'Kẻ Hủy Diệt Thời Gian' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-3-trailer.mp4' WHERE title = 'Thiên Đường Máu' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-4-trailer.mp4' WHERE title = 'Ma Xó' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-5-trailer.mp4' WHERE title = 'Bố Già' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-6-trailer.mp4' WHERE title = 'Doraemon: Đi Du Lịch Việt Nam' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-7-trailer.mp4' WHERE title = 'Dune: Hành Tinh Cát' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/inception.mp4' WHERE title = 'Inception' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-10-trailer.mp4' WHERE title = 'Avengers: Endgame' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-11-trailer.mp4' WHERE title = 'Spider-Man: No Way Home' AND (preview_url IS NULL OR preview_url = '');
UPDATE movies SET preview_url = '/previews/movie-13-trailer.mp4' WHERE title = 'Mưa đỏ' AND (preview_url IS NULL OR preview_url = '');
COMMIT;
