using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using MovieService.Helpers;

namespace ShowtimeService.Service.Interface
{
    public interface ISeatService
    {
        //Task<PagedResult<SeatResponse>> GetAllSeatsAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        //Task<PagedResult<SeatResponse>> GetSeatsByRoomIdAsync(long roomId, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<SeatResponse?> GetSeatByIdAsync(long seatId);
        Task<PagedResult<SeatResponse>> GenerateSeatAsync(GenerateSeatRequest request);
        Task<SeatResponse?> UpdateSeatTypeAsync(long seatId, UpdateSeatTypeRequest request);
        Task<bool> DeleteSeatAsync(long seatId);
    }
}
