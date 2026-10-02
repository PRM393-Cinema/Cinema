using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class BookingRepository : IBookingRepository
    {
        private readonly BookingDbContext _context;

        public BookingRepository(BookingDbContext context)
        {
            _context = context;
        }

        public async Task<Booking?> GetBookingByIdAsync(long id)
        {
            return await _context.Bookings
                .FirstOrDefaultAsync(b => b.Id == id);
        }

        public async Task<PagedList<Booking>> GetAllAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Booking> query = _context.Bookings;

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Booking>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<PagedList<Booking>> GetBookingByUserIdAsync(
            long userId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Booking> query = _context.Bookings
                .Where(b => b.UserId == userId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Booking>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<PagedList<Booking>> GetBookingByStatusAsync(
            string status,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Booking> query = _context.Bookings
                .Where(b => b.Status == status);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Booking>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Booking?> GetBookingByCodeAsync(string bookingCode)
        {
            return await _context.Bookings
                .FirstOrDefaultAsync(b => b.BookingCode == bookingCode);
        }

        public async Task<Booking> CreateBookingAsync(Booking booking)
        {
            _context.Bookings.Add(booking);

            await _context.SaveChangesAsync();

            return booking;
        }

        public async Task<Booking?> UpdateBookingAsync(
            long id,
            Booking booking)
        {
            var existingBooking = await _context.Bookings
                .FirstOrDefaultAsync(b => b.Id == id);

            if (existingBooking == null)
            {
                return null;
            }

            _context.Entry(existingBooking).CurrentValues.SetValues(booking);

            await _context.SaveChangesAsync();

            return existingBooking;
        }

        public async Task DeleteBookingAsync(long id)
        {
            var booking = await _context.Bookings
                .FirstOrDefaultAsync(b => b.Id == id);

            if (booking == null)
            {
                return;
            }

            _context.Bookings.Remove(booking);

            await _context.SaveChangesAsync();
        }

        public async Task<PagedList<Booking>> GetBookingByDateRangeAsync(
            DateTime start,
            DateTime end,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Booking> query = _context.Bookings
                .Where(b =>
                    b.CreatedAt >= start &&
                    b.CreatedAt <= end);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Booking>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        // Booking PENDING đã quá hạn giữ ghế không còn chiếm ghế (job sẽ chuyển sang EXPIRED)
        public async Task<List<long>> GetOccupiedSeatIdsAsync(long showtimeId, DateTime now)
        {
            return await _context.BookingSeats
                .Where(bs =>
                    bs.Booking.ShowtimeId == showtimeId &&
                    (
                        bs.Booking.Status == "CONFIRMED" ||
                        (
                            bs.Booking.Status == "PENDING" &&
                            (bs.Booking.ExpiresAt == null || bs.Booking.ExpiresAt > now)
                        )
                    ))
                .Select(bs => bs.SeatId)
                .Distinct()
                .OrderBy(seatId => seatId)
                .ToListAsync();
        }

        public async Task<List<long>> GetActiveBookingIdsByShowtimeAsync(long showtimeId)
        {
            return await _context.Bookings
                .AsNoTracking()
                .Where(b =>
                    b.ShowtimeId == showtimeId &&
                    (b.Status == "PENDING" || b.Status == "CONFIRMED"))
                .OrderBy(b => b.Id)
                .Select(b => b.Id)
                .ToListAsync();
        }

        public async Task<List<long>> GetOverduePendingBookingIdsAsync(DateTime now, int take)
        {
            return await _context.Bookings
                .AsNoTracking()
                .Where(b =>
                    b.Status == "PENDING" &&
                    b.ExpiresAt != null &&
                    b.ExpiresAt <= now)
                .OrderBy(b => b.ExpiresAt)
                .Select(b => b.Id)
                .Take(take)
                .ToListAsync();
        }

        // FOR UPDATE = @Lock trong Java
        public async Task<Booking?> GetBookingByIdForUpdateAsync(long id)
        {
            return await _context.Bookings
                .FromSqlInterpolated($@"
            SELECT *
            FROM bookings
            WHERE id = {id}
            FOR UPDATE")
                .AsTracking()
                .FirstOrDefaultAsync();
        }

        private static IQueryable<Booking> ApplySorting(
            IQueryable<Booking> query,
            string sortBy,
            string sortDir)
        {
            var descending =
                string.Equals(
                    sortDir,
                    "desc",
                    StringComparison.OrdinalIgnoreCase);

            return sortBy?.ToLower() switch
            {
                "id" => descending
                    ? query.OrderByDescending(b => b.Id)
                    : query.OrderBy(b => b.Id),

                "bookingcode" => descending
                    ? query.OrderByDescending(b => b.BookingCode)
                    : query.OrderBy(b => b.BookingCode),

                "status" => descending
                    ? query.OrderByDescending(b => b.Status)
                    : query.OrderBy(b => b.Status),

                "totalamount" => descending
                    ? query.OrderByDescending(b => b.TotalAmount)
                    : query.OrderBy(b => b.TotalAmount),

                "createdat" => descending
                    ? query.OrderByDescending(b => b.CreatedAt)
                    : query.OrderBy(b => b.CreatedAt),

                "expiresat" => descending
                    ? query.OrderByDescending(b => b.ExpiresAt)
                    : query.OrderBy(b => b.ExpiresAt),

                _ => query.OrderByDescending(b => b.CreatedAt)
            };
        }
    }
}
