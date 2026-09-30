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
                ReleaseDate = movie.ReleaseDate.Value,
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
