using Microsoft.EntityFrameworkCore;
using ShowtimeService.Data;
using MovieService.Helpers;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;
using ShowtimeService.DTOs.Request;

namespace ShowtimeService.Repository.Impl
{
    public class ShowtimeRepository : IShowtimeRepository
    {
        private readonly ShowtimeDbContext _context;

        public ShowtimeRepository(ShowtimeDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Showtime>> GetAllShowtimesAsync(int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Showtimes.AsNoTracking();

            return await PagedList<Showtime>.CreateAsync(query, pageNumber, pageSize);
        }

        public async Task<Showtime?> GetShowtimeByIdAsync(long showtimeId)
        {
            return await _context.Showtimes.FindAsync(showtimeId);
        }

        public async Task<Showtime> CreateShowtimeAsync(ShowtimeRequest request)
        {
            var showtime = new Showtime
            {
                MovieId = request.MovieId,
                RoomId = request.RoomId,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                Price = request.Price,
                Status = string.IsNullOrWhiteSpace(request.Status) ? "OPEN" : request.Status
            };

            _context.Showtimes.Add(showtime);

            await _context.SaveChangesAsync();

            return showtime;
        }

        public async Task<Showtime?> UpdateShowtimeAsync(long showtimeId, ShowtimeRequest request)
        {
            var existingShowtime = await _context.Showtimes.FindAsync(showtimeId);
            if (existingShowtime == null)
            {
                return null;
            }
            _context.Entry(existingShowtime).CurrentValues.SetValues(request);
            await _context.SaveChangesAsync();
            return existingShowtime;
        }

        public async Task<bool> DeleteShowtimeAsync(long showtimeId)
        {
            var existingShowtime = await _context.Showtimes.FindAsync(showtimeId);
            if (existingShowtime == null)
            {
                return false;
            }
            _context.Showtimes.Remove(existingShowtime);
            await _context.SaveChangesAsync();
            return true;
        }

        //public async Task<PagedList<Showtime>> GetShowtimesByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir)
        //{
        //    var query = _context.Showtimes
        //        .AsNoTracking()
        //        .Where(s => s.Status == status);
        //    return await PagedList<Showtime>.CreateAsync(query, pageNumber, pageSize);
        //}

        //public async Task<PagedList<Showtime>> GetShowtimesByMovieIdAndStatusAsync(long movieId, int pageNumber, int pageSize, string sortBy, string sortDir)
        //{
        //    var query = _context.Showtimes
        //        .AsNoTracking()
        //        .Where(s => s.MovieId == movieId && s.Status == "OPEN");
        //    return await PagedList<Showtime>.CreateAsync(query, pageNumber, pageSize);
        //}

        //public async Task<PagedList<Showtime>> GetShowtimesByStartTimeBetweenAsync(DateTime start, DateTime end, int pageNumber, int pageSize, string sortBy, string sortDir)
        //{
        //    var query = _context.Showtimes
        //        .AsNoTracking()
        //        .Where(s => s.StartTime >= start && s.StartTime <= end);
        //    return await PagedList<Showtime>.CreateAsync(query, pageNumber, pageSize);
        //}

        public async Task<PagedList<Showtime>> GetOpenShowtimesAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var query = _context.Showtimes
                .AsNoTracking()
                .Where(x => x.StartTime > DateTime.Now);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Showtime>.CreateAsync(
                query, 
                pageNumber,
                pageSize
                );
        }

        public async Task<PagedList<Showtime>> GetShowtimesByMovieAsync(
            long movieId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var query = _context.Showtimes
                .AsNoTracking()
                .Where(x => x.MovieId == movieId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Showtime>.CreateAsync(
                query,
                pageNumber,
                pageSize
                );
        }

        public async Task<PagedList<Showtime>> GetShowtimesByDateRangeAsync(
            DateTime start,
            DateTime end,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var query = _context.Showtimes
                .AsNoTracking()
                .Where(x =>
                    x.StartTime >= start &&
                    x.StartTime < end);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Showtime>.CreateAsync(query, pageNumber, pageSize);
        }

        public async Task<bool> HasScheduleConflictAsync(
            long roomId,
            DateTime startTime,
            DateTime endTime,
            long? excludeShowtimeId = null)
        {
            var query = _context.Showtimes
                .AsNoTracking()
                .Where(x =>
                    x.RoomId == roomId &&
                    x.StartTime < endTime &&
                    x.EndTime > startTime);

            if (excludeShowtimeId.HasValue)
            {
                query = query.Where(x =>
                    x.Id != excludeShowtimeId.Value);
            }

            return await query.AnyAsync();
        }

        private static IQueryable<Showtime> ApplySorting(
            IQueryable<Showtime> query,
            string sortBy,
            string sortDir)
        {
            var descending =
                string.Equals(
                    sortDir,
                    "desc",
                    StringComparison.OrdinalIgnoreCase);

            return sortBy?.ToLower() switch
            {
                "showtimeid" =>
                    descending
                        ? query.OrderByDescending(x => x.Id)
                        : query.OrderBy(x => x.Id),

                "movieid" =>
                    descending
                        ? query.OrderByDescending(x => x.MovieId)
                        : query.OrderBy(x => x.MovieId),

                "roomid" =>
                    descending
                        ? query.OrderByDescending(x => x.RoomId)
                        : query.OrderBy(x => x.RoomId),

                "starttime" =>
                    descending
                        ? query.OrderByDescending(x => x.StartTime)
                        : query.OrderBy(x => x.StartTime),

                "endtime" =>
                    descending
                        ? query.OrderByDescending(x => x.EndTime)
                        : query.OrderBy(x => x.EndTime),

                _ =>
                    query.OrderBy(x => x.StartTime)
            };
        }

        public async Task<List<Showtime>> GetShowtimesByRoomIdAsync(long roomId)
        {
            return await _context.Showtimes
                .Where(x => x.RoomId == roomId)
                .ToListAsync();
        }

        public async Task<bool> ExistsByRoomIdAsync(long roomId)
        {
            return await _context.Seats
                .AnyAsync(x => x.RoomId == roomId);
        }
    }
}
