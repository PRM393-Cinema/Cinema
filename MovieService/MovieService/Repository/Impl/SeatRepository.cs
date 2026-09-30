using Microsoft.EntityFrameworkCore;
using ShowtimeService.Data;
using MovieService.Helpers;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;

namespace ShowtimeService.Repository.Impl
{
    public class SeatRepository : ISeatRepository
    {
        private readonly ShowtimeDbContext _context;

        public SeatRepository(ShowtimeDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Seat>> GetSeatsByRoomAsync(long roomId, int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var query = _context.Seats
                .AsNoTracking()
                .Where(s => s.RoomId == roomId);
            return await PagedList<Seat>.CreateAsync(query, pageNumber, pageSize);
        }

        // Toàn bộ ghế của phòng (không phân trang) để vẽ sơ đồ ghế — số lượng bị giới hạn bởi sức chứa phòng.
        // Sắp theo độ dài tên hàng trước để hàng "AA" đứng sau "Z".
        public async Task<List<Seat>> GetAllSeatsByRoomAsync(long roomId)
        {
            return await _context.Seats
                .AsNoTracking()
                .Where(s => s.RoomId == roomId)
                .OrderBy(s => s.SeatRow.Length)
                .ThenBy(s => s.SeatRow)
                .ThenBy(s => s.SeatNumber)
                .ToListAsync();
        }

        public async Task<Seat?> GetSeatByIdAsync(long seatId)
        {
            return await _context.Seats.FindAsync(seatId);
        }

        public async Task<List<Seat>> GetSeatsByIdsAsync(IEnumerable<long> seatIds)
        {
            var ids = seatIds.Distinct().ToList();

            return await _context.Seats
                .AsNoTracking()
                .Where(s => ids.Contains(s.Id))
                .ToListAsync();
        }

        public async Task<Seat?> UpdateSeatAsync(long seatId, Seat seat)
        {
            var existingSeat = await _context.Seats.FindAsync(seatId);
            if (existingSeat == null)
            {
                return null;
            }
            _context.Entry(existingSeat).CurrentValues.SetValues(seat);
            await _context.SaveChangesAsync();
            return existingSeat;
        }

        public async Task<bool> DeleteSeatAsync(long seatId)
        {
            var existingSeat = await _context.Seats.FindAsync(seatId);
            if (existingSeat == null)
            {
                return false;
            }
            _context.Seats.Remove(existingSeat);
            await _context.SaveChangesAsync();
            return true;
        }

        public async Task<bool> ExistByRoomIdAndSeatRowAndSeatNumberAsync(long roomId, string seatRow, int seatNumber)
        {
            return await _context.Seats
                .AnyAsync(s => s.RoomId == roomId && s.SeatRow == seatRow && s.SeatNumber == seatNumber);
        }

        public async Task<PagedList<Seat>> GenerateSeatsAsync(
            long roomId,
            int rows,
            int seatsPerRow)
        {
            var seats = new List<Seat>();

            for (int row = 1; row <= rows; row++)
            {
                for (int seatNumber = 1; seatNumber <= seatsPerRow; seatNumber++)
                {
                    seats.Add(new Seat
                    {
                        RoomId = roomId,
                        SeatRow = ((char)('A' + row - 1)).ToString(),
                        SeatNumber = seatNumber,
                        SeatType = "NORMAL"
                    });
                }
            }

            await _context.Seats.AddRangeAsync(seats);
            await _context.SaveChangesAsync();

            var query = _context.Seats
                .Where(x => x.RoomId == roomId)
                .OrderBy(x => x.SeatRow)
                .ThenBy(x => x.SeatNumber);

            return await PagedList<Seat>.CreateAsync(
                query,
                1,
                seats.Count);
        }
    }
}
