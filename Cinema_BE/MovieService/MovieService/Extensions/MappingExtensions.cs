using MovieService.DTOs.Response;
using MovieService.Helpers;
using MovieService.Models;

namespace MovieService.Extensions
{
    public static class MappingExtensions
    {
        public static MovieResponse ToResponse(this Movie movie)
        {
            return new MovieResponse
            {
                Id = movie.Id,
                Title = movie.Title,
                Description = movie.Description,
                DurationMinutes = movie.DurationMinutes,
                Genre = movie.Genre,
                Language = movie.Language,
                // Phim chưa có ngày phát hành: trả 0001-01-01 thay vì lỗi 500 cho cả danh sách (app coi là không có ngày)
                ReleaseDate = movie.ReleaseDate ?? default,
                PosterUrl = movie.PosterUrl,
                TrailerUrl = movie.TrailerUrl,
                Status = movie.Status,
                CreatedAt = movie.CreatedAt
            };
        }

        public static PagedResult<MovieResponse> ToPagedResult(this PagedList<Movie> movies)
        {
            return new PagedResult<MovieResponse>
            {
                Items = movies.Select(m => m.ToResponse()).ToList(),
                PageNumber = movies.PageNumber,
                PageSize = movies.PageSize,
                TotalPages = movies.TotalPages,
                TotalCount = movies.TotalCount
            };
        }
    }
}
