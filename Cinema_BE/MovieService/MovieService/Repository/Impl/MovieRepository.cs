using Microsoft.EntityFrameworkCore;
using MovieService.Data;
using MovieService.Helpers;
using MovieService.Models;
using MovieService.Repository.Interface;

namespace MovieService.Repository.Impl
{
    public class MovieRepository : IMovieRepository
    {
        private readonly MovieDbContext _context;

        public MovieRepository(MovieDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Movie>> GetAllMoviesAsync(int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Movies.AsNoTracking();

            return await PagedList<Movie>.CreateAsync(Sort(query, sortBy, sortDir), pageNumber, pageSize);
        }

        public async Task<PagedList<Movie>> GetByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Movies
            .AsNoTracking()
            .Where(m => m.Status == status);

            return await PagedList<Movie>.CreateAsync(Sort(query, sortBy, sortDir), pageNumber, pageSize);
        }

        public async Task<PagedList<Movie>> SearchByTitleAsync(string keyword, int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Movies.AsNoTracking();

            if (!string.IsNullOrEmpty(keyword))
            {
                // Không phân biệt hoa thường: "dune" tìm được "Dune"
                var lowered = keyword.ToLower();
                query = query.Where(m => m.Title.ToLower().Contains(lowered));
            }
            return await PagedList<Movie>.CreateAsync(Sort(query, sortBy, sortDir), pageNumber, pageSize);
        }

        // Không sắp xếp thì Postgres trả hàng theo vị trí lưu trữ: phim vừa sửa nhảy sang chỗ khác,
        // có khi sang trang khác. Id là khoá phụ để các phim cùng giá trị luôn đứng cùng một thứ tự.
        private static IQueryable<Movie> Sort(IQueryable<Movie> query, string sortBy, string sortDir)
        {
            var descending = string.Equals(sortDir, "desc", StringComparison.OrdinalIgnoreCase);
            IOrderedQueryable<Movie> ordered = sortBy?.Trim().ToLowerInvariant() switch
            {
                "title" => descending ? query.OrderByDescending(m => m.Title) : query.OrderBy(m => m.Title),
                "releasedate" => descending ? query.OrderByDescending(m => m.ReleaseDate) : query.OrderBy(m => m.ReleaseDate),
                "durationminutes" => descending ? query.OrderByDescending(m => m.DurationMinutes) : query.OrderBy(m => m.DurationMinutes),
                _ => descending ? query.OrderByDescending(m => m.CreatedAt) : query.OrderBy(m => m.CreatedAt),
            };
            return descending ? ordered.ThenByDescending(m => m.Id) : ordered.ThenBy(m => m.Id);
        }

        public async Task<Movie?> GetMovieByIdAsync(long id)
        {
            return await _context.Movies.FirstOrDefaultAsync(m => m.Id == id);
        }

        public async Task<Movie> CreateMovieAsync(Movie movie)
        {
            _context.Movies.Add(movie);
            await _context.SaveChangesAsync();
            return movie;
        }

        public async Task<Movie> UpdateMovieAsync(Movie movie)
        {
            _context.Movies.Update(movie);
            await _context.SaveChangesAsync();
            return movie;
        }

        public async Task DeleteMovieAsync(Movie movie)
        {
            _context.Movies.Remove(movie);
            await _context.SaveChangesAsync();
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }

        public async Task<bool> ExistMovieAsync(string title)
        {
            if (string.IsNullOrWhiteSpace(title)) return false;

            var cleanTitle = title.Trim().ToLower();
            return await _context.Movies.AnyAsync(m => m.Title.ToLower() == cleanTitle);
        }

        public async Task<bool> ExistsByTitleExceptIdAsync(string title, long id)
        {
            if (string.IsNullOrWhiteSpace(title)) return false;
            var cleanTitle = title.Trim().ToLower();
            return await _context.Movies.AnyAsync(m => m.Title.ToLower() == cleanTitle && m.Id != id);
        }
    }
}
