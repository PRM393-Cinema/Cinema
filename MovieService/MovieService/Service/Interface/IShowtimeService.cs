using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using MovieService.Helpers;

namespace ShowtimeService.Service.Interface
{
    public interface IShowtimeService
    {
        Task<PagedResult<ShowtimeResponse>> GetAllShowtimesAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<ShowtimeResponse?> GetShowtimeByIdAsync(long showtimeId);
        Task<ShowtimeResponse> CreateShowtimeAsync(ShowtimeRequest request);
        Task<ShowtimeResponse?> UpdateShowtimeAsync(long showtimeId, ShowtimeRequest request);
        Task<bool> DeleteShowtimeAsync(long showtimeId);
        Task<PagedResult<ShowtimeResponse>> GetOpenShowtimesAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedResult<ShowtimeResponse>> GetShowtimesByMovieAsync(long movieId, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedResult<ShowtimeResponse>> GetShowtimesByDateRangeAsync(DateTime start, DateTime end, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<List<ShowtimeSeatResponse>> GetSeatsForBookingAsync(long showtimeId, List<long> seatIds);
    }
}
