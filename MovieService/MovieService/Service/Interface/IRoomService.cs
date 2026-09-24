using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using MovieService.Helpers;

namespace ShowtimeService.Service.Interface
{
    public interface IRoomService
    {
        Task<PagedResult<RoomResponse>> GetAllRoomsAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<RoomResponse?> GetRoomByIdAsync(long roomId);
        Task<RoomResponse> CreateRoomAsync(RoomRequest request);
        Task<RoomResponse?> UpdateRoomAsync(long roomId, RoomRequest request);
        Task<bool> DeleteRoomAsync(long roomId);
        Task<PagedResult<RoomResponse>> SearchRoomsAsync(string keyword, int pageNumber, int pageSize, string sortBy, string sortDir);
    }
}
