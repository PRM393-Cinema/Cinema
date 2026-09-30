using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IBookingRepository
    {
        Task<PagedList<Booking>> GetAllAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Booking?> GetBookingByIdAsync(long Id);
        Task<PagedList<Booking>> GetBookingByUserIdAsync(long userId, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<PagedList<Booking>> GetBookingByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Booking?> GetBookingByCodeAsync(string bookingCode);
        Task<Booking> CreateBookingAsync(Booking booking);
        Task<Booking?> UpdateBookingAsync(long id, Booking booking);
        Task DeleteBookingAsync(long id);
        Task<PagedList<Booking>> GetBookingByDateRangeAsync(
            DateTime start,
            DateTime end,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);
        Task<List<long>> GetOccupiedSeatIdsAsync(long showtimeId);
        Task<Booking?> GetBookingByIdForUpdateAsync(long id);
    }
}
