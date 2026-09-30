using MovieService.DTOs.Request;
using MovieService.DTOs.Response;
using MovieService.Exception;
using MovieService.Extensions;
using MovieService.Helpers;
using MovieService.Models;
using MovieService.Repository.Interface;
using MovieService.Service.Interface;

namespace MovieService.Service.Impl
{
    public class MovieService : IMovieService
    {
        private readonly IMovieRepository _movieRepository;

        public MovieService(IMovieRepository movieRepository)
        {
            _movieRepository = movieRepository;
        }

        // ======= GET ALL MOVIES =======
        public async Task<PagedResult<MovieResponse>> GetAllMoviesAsync(
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var p = PaginationUtils.Normalize(page, size, sortBy, sortDir);
            var movies = await _movieRepository.GetAllMoviesAsync(p.PageNumber, p.PageSize, p.SortBy, p.SortDir);
            return movies.ToPagedResult();
        }

        // ======= GET MOVIE BY ID =======
        public async Task<MovieResponse> GetMovieByIdAsync(long id)
        {
            var movie = await _movieRepository.GetMovieByIdAsync(id);

            if (movie is null)
            {
                throw new NotFoundException($"Movie with ID {id} was not found.");
            }

            return movie.ToResponse();
        }

        // ======= GET BY STATUS =======
        public async Task<PagedResult<MovieResponse>> GetByStatusAsync(
            string status,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            if (string.IsNullOrWhiteSpace(status))
            {
                throw new BusinessException("Status parameter is required.");
            }

            var p = PaginationUtils.Normalize(page, size, sortBy, sortDir);

            var movies = await _movieRepository.GetByStatusAsync(
                status.Trim(),
                p.PageNumber,
                p.PageSize,
                p.SortBy,
                p.SortDir);

            return movies.ToPagedResult();
        }

        // ======= SEARCH MOVIES BY TITLE =======
        public async Task<PagedResult<MovieResponse>> SearchMoviesAsync(
            string keyword,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            if (string.IsNullOrWhiteSpace(keyword))
            {
                throw new BusinessException("Search keyword is required.");
            }

            var p = PaginationUtils.Normalize(page, size, sortBy, sortDir);

            var movies = await _movieRepository.SearchByTitleAsync(
                keyword.Trim(),
                p.PageNumber,
                p.PageSize,
                p.SortBy,
                p.SortDir);

            return movies.ToPagedResult();
        }

        // ======= CREATE MOVIE =======
        public async Task<MovieResponse> CreateMovieAsync(MovieRequest request)
        {
            var title = request.Title.Trim();

            if (await _movieRepository.ExistMovieAsync(title))
            {
                throw new BusinessException($"Movie with title '{title}' already exists.");
            }

            var movie = new Movie
            {
                Title = title,
                Description = request.Description?.Trim(),
                DurationMinutes = request.DurationMinutes,
                Genre = request.Genre?.Trim(),
                Language = request.Language?.Trim(),
                ReleaseDate = DateOnly.FromDateTime(request.ReleaseDate), // FIX: Convert DateTime to DateOnly
                PosterUrl = request.PosterUrl?.Trim(),
                TrailerUrl = request.TrailerUrl?.Trim(),
                Status = "ACTIVE", // Đặt mặc định trạng thái
                CreatedAt = DateTime.Now
            };

            await _movieRepository.CreateMovieAsync(movie);
            await _movieRepository.SaveChangesAsync();

            return movie.ToResponse();
        }

        // ======= UPDATE MOVIE =======
        public async Task<MovieResponse> UpdateMovieAsync(long id, MovieRequest request)
        {
            var movie = await _movieRepository.GetMovieByIdAsync(id)
                ?? throw new NotFoundException($"Movie with ID {id} was not found.");

            var title = request.Title.Trim();
            var isDuplicate = await _movieRepository.ExistsByTitleExceptIdAsync(title, id);
            if (isDuplicate)
            {
                throw new BusinessException($"Movie with title '{title}' already exists.");
            }

            movie.Title = title;
            movie.Description = request.Description?.Trim() ?? string.Empty;
            movie.DurationMinutes = request.DurationMinutes;
            movie.Genre = request.Genre?.Trim();
            movie.Language = request.Language?.Trim();
            movie.ReleaseDate = DateOnly.FromDateTime(request.ReleaseDate);
            movie.PosterUrl = request.PosterUrl?.Trim();
            movie.TrailerUrl = request.TrailerUrl?.Trim();

            await _movieRepository.UpdateMovieAsync(movie);
            await _movieRepository.SaveChangesAsync();

            return movie.ToResponse();
        }

        // ======= DELETE MOVIE =======
        public async Task DeleteMovieAsync(long id)
        {
            var movie = await _movieRepository.GetMovieByIdAsync(id);
            if (movie is null)
            {
                throw new NotFoundException($"Movie with ID {id} was not found.");
            }

            if (string.Equals(movie.Status, "INACTIVE", StringComparison.OrdinalIgnoreCase))
            {
                throw new BusinessException($"Movie with ID {id} is already inactive.");
            }

            // Soft delete: Chuyển trạng thái sang INACTIVE
            movie.Status = "INACTIVE";

            await _movieRepository.UpdateMovieAsync(movie);
            await _movieRepository.SaveChangesAsync();
        }
    }
}