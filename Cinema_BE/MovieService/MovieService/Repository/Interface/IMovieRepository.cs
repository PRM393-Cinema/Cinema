using MovieService.Helpers;
using MovieService.Models;

namespace MovieService.Repository.Interface
{
    public interface IMovieRepository
    {
        Task<PagedList<Movie>> GetAllMoviesAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedList<Movie>> GetByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedList<Movie>> SearchByTitleAsync(string keyword, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Movie?> GetMovieByIdAsync(long id);
        Task<Movie> CreateMovieAsync(Movie movie);
        Task<Movie> UpdateMovieAsync(Movie movie);
        Task DeleteMovieAsync(Movie movie);
        Task SaveChangesAsync();
        Task<bool> ExistMovieAsync(string title);
        Task<bool> ExistsByTitleExceptIdAsync(string title, long id);
    }
}
