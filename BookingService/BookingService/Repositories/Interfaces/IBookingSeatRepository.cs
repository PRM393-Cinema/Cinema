using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IBookingSeatRepository
    {
        //Task<BookingSeat?> GetByIdAsync(long id);
        //Task<PagedList<BookingSeat>> GetAllAsync(int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<List<BookingSeat>> GetByBookingIdAsync(long bookingId);
        Task<BookingSeat> AddAsync(BookingSeat bookingSeat);

        //Task<BookingSeat?> GetByBookingIdAndSeatIdAsync(long bookingId, long seatId);
        //Task<bool> ExistsAsync(long bookingId, long seatId);
        //Task DeleteAsync(BookingSeat bookingSeat);
    }
}
