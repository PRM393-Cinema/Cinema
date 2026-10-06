using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.Models;

namespace ShowtimeService.Repository.Interface
{
    public interface IShowtimeRepository
    {
        Task<PagedList<Showtime>> GetAllShowtimesAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedList<Showtime>> GetOpenShowtimesAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Showtime?> GetShowtimeByIdAsync(long showtimeId);
        Task<Showtime> CreateShowtimeAsync(ShowtimeRequest request);
        Task<Showtime?> UpdateShowtimeAsync(long showtimeId, ShowtimeRequest request);
        Task<Showtime?> UpdateStatusAsync(long showtimeId, string status);
        Task<PagedList<Showtime>> GetShowtimesByMovieAsync(
        long movieId,
        int pageNumber,
        int pageSize,
        string sortBy,
        string sortDir);

        Task<PagedList<Showtime>> GetOpenShowtimesByMovieAsync(
            long movieId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);

        Task<PagedList<Showtime>> GetShowtimesByDateRangeAsync(
            DateTime start,
            DateTime end,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);

        Task<bool> HasScheduleConflictAsync(
            long roomId,
            DateTime startTime,
            DateTime endTime,
            long? excludeShowtimeId = null);
        Task<List<Showtime>> GetShowtimesByRoomIdAsync(long roomId);
        Task<bool> ExistsByRoomIdAsync(long roomId);
    }
}
