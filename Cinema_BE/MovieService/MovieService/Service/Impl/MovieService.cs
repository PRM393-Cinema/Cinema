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

        public async Task<PagedResult<MovieResponse>> BrowseAsync(
            string? when,
            string? genre,
            string? keyword,
            int page,
            int size)
        {
            var comingSoon = (when ?? "now").Trim().ToLowerInvariant() switch
            {
                "now" => false,
                "soon" => true,
                _ => throw new BusinessException("When must be now or soon.")
            };

            var p = PaginationUtils.Normalize(page, size, "createdAt", "desc");
            var movies = await _movieRepository.BrowseAsync(
                comingSoon,
                genre,
                keyword,
                DateOnly.FromDateTime(DateTime.Now),
                p.PageNumber,
                p.PageSize);
            return movies.ToPagedResult();
        }

        public async Task<List<string>> GetGenresAsync()
        {
            return (await _movieRepository.GetActiveGenresAsync())
                .SelectMany(genres => genres.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Order(StringComparer.Create(new System.Globalization.CultureInfo("vi-VN"), true))
                .ToList();
        }

        private static string? Blank(string? value) =>
            string.IsNullOrWhiteSpace(value) ? null : value.Trim();

        private static readonly string[] AgeRatings = ["P", "K", "T13", "T16", "T18"];

        // null khi bỏ trống; sai mức thì 400
        private static string? NormalizeAgeRating(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return null;
            }

            var rating = value.Trim().ToUpperInvariant();
            return AgeRatings.Contains(rating)
                ? rating
                : throw new BusinessException("Age rating must be P, K, T13, T16 or T18.");
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
                AgeRating = NormalizeAgeRating(request.AgeRating) ?? "P",
                Director = Blank(request.Director),
                Cast = Blank(request.Cast),
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
            movie.AgeRating = NormalizeAgeRating(request.AgeRating) ?? movie.AgeRating;
            movie.Director = Blank(request.Director);
            movie.Cast = Blank(request.Cast);

            // Admin chiếu lại phim đã ngừng (DELETE chỉ chuyển sang INACTIVE)
            if (!string.IsNullOrWhiteSpace(request.Status))
            {
                var status = request.Status.Trim().ToUpperInvariant();
                if (status is not ("ACTIVE" or "INACTIVE"))
                {
                    throw new BusinessException("Status must be ACTIVE or INACTIVE.");
                }
                movie.Status = status;
            }

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