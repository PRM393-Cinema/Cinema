using MovieService.DTOs.Request;
using MovieService.DTOs.Response;
using MovieService.Helpers;

namespace MovieService.Service
{
    public interface IMovieService
    {
        Task<PagedResult<MovieResponse>> GetAllMoviesAsync(int page, int size, string sortBy, string sortDir);

        Task<PagedResult<MovieResponse>> GetByStatusAsync(string status, int page, int size, string sortBy, string sortDir);

        Task<MovieResponse> GetMovieByIdAsync(long id);

        Task<MovieResponse> CreateMovieAsync(MovieRequest request);

        Task<MovieResponse> UpdateMovieAsync(long id, MovieRequest request);

        Task DeleteMovieAsync(long id);

        Task<PagedResult<MovieResponse>> SearchMoviesAsync(string keyword, int page, int size, string sortBy, string sortDir);
    }
}
