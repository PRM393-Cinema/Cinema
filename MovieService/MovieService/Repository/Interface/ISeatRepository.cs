using MovieService.Helpers;
using ShowtimeService.Models;

namespace ShowtimeService.Repository.Interface
{
    public interface ISeatRepository
    {
        Task<PagedList<Seat>> GetSeatsByRoomAsync(long roomId, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Seat?> GetSeatByIdAsync(long seatId);
        Task<PagedList<Seat>> GenerateSeatsAsync (long roomId, int rows, int seatsPerRow);
        Task<Seat?> UpdateSeatAsync(long seatId, Seat seat);
        Task<bool> DeleteSeatAsync(long seatId);
        Task<bool> ExistByRoomIdAndSeatRowAndSeatNumberAsync(long roomId, string seatRow, int seatNumber);
    }
}
