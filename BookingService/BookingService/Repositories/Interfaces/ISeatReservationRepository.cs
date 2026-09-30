using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface ISeatReservationRepository
    {
        //Task<SeatReservation?> GetByIdAsync(long id);
        //Task<PagedList<SeatReservation>> GetByShowtimeIdAsync(long showtimeId, int pageNumber, int pageSize, string sortBy, string sortDir);
        //Task<SeatReservation?> GetByShowtimeIdAndSeatIdAsync(long showtimeId, long seatId);
        //Task<bool> ExistsAsync(long showtimeId, long seatId);
        //Task DeleteAsync(SeatReservation seatReservation);
        //Task<List<long>> GetOccupiedSeatIdsAsync(long showtimeId);
        //Task<List<SeatReservation>> GetExpiredHeldReservationsAsync(DateTime now);

        Task<SeatReservation> AddAsync(SeatReservation seatReservation);
        Task UpdateAsync(SeatReservation seatReservation);
        Task<SeatReservation?> GetByShowtimeIdAndSeatIdForUpdateAsync(
            long showtimeId,
            long seatId);
    }
}
