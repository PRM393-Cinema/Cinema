using Microsoft.EntityFrameworkCore;
using ShowtimeService.Data;
using MovieService.Helpers;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;

namespace ShowtimeService.Repository.Impl
{
    public class RoomRepository : IRoomRepository
    {
        private readonly ShowtimeDbContext _context;

        public RoomRepository(ShowtimeDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Room>> GetAllRoomsAsync(int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Rooms.AsNoTracking();
            return await PagedList<Room>.CreateAsync(Sort(query, sortBy, sortDir), pageNumber, pageSize);
        }

        public async Task<Room?> GetRoomByIdAsync(long roomId)
        {
            return await _context.Rooms.FindAsync(roomId);
        }

        public async Task<PagedList<Room>> SearchRoomsAsync(string roomName, int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Rooms.AsNoTracking();
            if (!string.IsNullOrEmpty(roomName))
            {
                // Không phân biệt hoa thường
                var lowered = roomName.ToLower();
                query = query.Where(m => m.Name.ToLower().Contains(lowered));
            }

            return await PagedList<Room>.CreateAsync(Sort(query, sortBy, sortDir), pageNumber, pageSize);
        }

        // Mặc định theo tên phòng; Id là khoá phụ để thứ tự giữa các trang luôn cố định.
        private static IQueryable<Room> Sort(IQueryable<Room> query, string sortBy, string sortDir)
        {
            var descending = string.Equals(sortDir, "desc", StringComparison.OrdinalIgnoreCase);
            IOrderedQueryable<Room> ordered = sortBy?.Trim().ToLowerInvariant() switch
            {
                "id" => descending ? query.OrderByDescending(r => r.Id) : query.OrderBy(r => r.Id),
                "totalseats" => descending ? query.OrderByDescending(r => r.TotalSeats) : query.OrderBy(r => r.TotalSeats),
                _ => descending ? query.OrderByDescending(r => r.Name) : query.OrderBy(r => r.Name),
            };
            return descending ? ordered.ThenByDescending(r => r.Id) : ordered.ThenBy(r => r.Id);
        }

        public async Task<Room> CreateRoomAsync(Room room)
        {
            _context.Rooms.Add(room);
            await _context.SaveChangesAsync();
            return room;
        }

        public async Task<Room?> UpdateRoomAsync(long roomId, Room room)
        {
            var existingRoom = await _context.Rooms.FindAsync(roomId);
            if (existingRoom == null)
            {
                return null;
            }
            _context.Entry(existingRoom).CurrentValues.SetValues(room);
            await _context.SaveChangesAsync();
            return existingRoom;
        }

        public async Task<bool> DeleteRoomAsync(long roomId)
        {
            var existingRoom = await _context.Rooms.FindAsync(roomId);
            if (existingRoom == null)
            {
                return false;
            }
            _context.Rooms.Remove(existingRoom);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> ExistRoomAsync(string name)
        {
            return await _context.Rooms.AnyAsync(r => r.Name == name);
        }
    }
}
