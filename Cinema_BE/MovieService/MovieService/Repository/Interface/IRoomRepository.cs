using MovieService.Helpers;
using ShowtimeService.Models;

namespace ShowtimeService.Repository.Interface
{
    public interface IRoomRepository
    {
        Task<PagedList<Room>> GetAllRoomsAsync(int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Room?> GetRoomByIdAsync(long roomId);
        Task<PagedList<Room>> SearchRoomsAsync(string roomName, int pageNumber, int pageSize, string sortBy, string sortDir);
        Task<Room> CreateRoomAsync(Room room);
        Task<Room?> UpdateRoomAsync(long roomId, Room room);
        Task<bool> DeleteRoomAsync(long roomId);
        Task<bool> ExistRoomAsync(string name);
    }
}
