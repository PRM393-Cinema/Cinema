using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class SeatReservationRepository : ISeatReservationRepository
    {
        private readonly BookingDbContext _context;

        public SeatReservationRepository(BookingDbContext context)
        {
            _context = context;
        }

        //public async Task<SeatReservation?> GetByIdAsync(long id)
        //{
        //    return await _context.SeatReservations
        //        .FirstOrDefaultAsync(sr => sr.Id == id);
        //}

        //public async Task<PagedList<SeatReservation>> GetByShowtimeIdAsync(
        //    long showtimeId,
        //    int pageNumber,
        //    int pageSize,
        //    string sortBy,
        //    string sortDir)
        //{
        //    IQueryable<SeatReservation> query = _context.SeatReservations
        //        .Where(sr => sr.ShowtimeId == showtimeId);

        //    query = ApplySorting(query, sortBy, sortDir);

        //    return await PagedList<SeatReservation>.CreateAsync(
        //        query,
        //        pageNumber,
        //        pageSize);
        //}

        //public async Task<SeatReservation?> GetByShowtimeIdAndSeatIdAsync(
        //    long showtimeId,
        //    long seatId)
        //{
        //    return await _context.SeatReservations
        //        .FirstOrDefaultAsync(sr =>
        //            sr.ShowtimeId == showtimeId &&
        //            sr.SeatId == seatId);
        //}

        //public async Task<bool> ExistsAsync(
        //    long showtimeId,
        //    long seatId)
        //{
        //    return await _context.SeatReservations
        //        .AnyAsync(sr =>
        //            sr.ShowtimeId == showtimeId &&
        //            sr.SeatId == seatId);
        //}

        public async Task<SeatReservation> AddAsync(
            SeatReservation seatReservation)
        {
            _context.SeatReservations.Add(seatReservation);

            await _context.SaveChangesAsync();

            return seatReservation;
        }

        public async Task UpdateAsync(
            SeatReservation seatReservation)
        {
            _context.SeatReservations.Update(seatReservation);

            await _context.SaveChangesAsync();
        }

        //public async Task DeleteAsync(
        //    SeatReservation seatReservation)
        //{
        //    _context.SeatReservations.Remove(seatReservation);

        //    await _context.SaveChangesAsync();
        //}

        //public async Task<List<long>> GetOccupiedSeatIdsAsync(long showtimeId)
        //{
        //    var now = DateTime.UtcNow;

        //    return await _context.SeatReservations
        //        .Where(sr =>
        //            sr.ShowtimeId == showtimeId &&
        //            (
        //                sr.Status == "BOOKED" ||
        //                (
        //                    sr.Status == "HELD" &&
        //                    sr.HeldUntil.HasValue &&
        //                    sr.HeldUntil.Value > now
        //                )
        //            ))
        //        .Select(sr => sr.SeatId)
        //        .Distinct()
        //        .ToListAsync();
        //}

        //public async Task<List<SeatReservation>> GetExpiredHeldReservationsAsync(DateTime now)
        //{
        //    return await _context.SeatReservations
        //        .Where(sr =>
        //            sr.Status == "HELD" &&
        //            sr.HeldUntil.HasValue &&
        //            sr.HeldUntil.Value <= now)
        //        .ToListAsync();
        //}

        public async Task<SeatReservation?> GetByShowtimeIdAndSeatIdForUpdateAsync(
            long showtimeId,
            long seatId)
        {
            return await _context.SeatReservations
                .FromSqlInterpolated($@"
            SELECT *
            FROM seat_reservations
            WHERE showtime_id = {showtimeId}
              AND seat_id = {seatId}
            FOR UPDATE")
                .AsTracking()
                .FirstOrDefaultAsync();
        }

        private static IQueryable<SeatReservation> ApplySorting(
            IQueryable<SeatReservation> query,
            string sortBy,
            string sortDir)
        {
            bool descending = string.Equals(
                sortDir,
                "desc",
                StringComparison.OrdinalIgnoreCase);

            return sortBy?.ToLowerInvariant() switch
            {
                "id" => descending
                    ? query.OrderByDescending(sr => sr.Id)
                    : query.OrderBy(sr => sr.Id),

                "showtimeid" => descending
                    ? query.OrderByDescending(sr => sr.ShowtimeId)
                    : query.OrderBy(sr => sr.ShowtimeId),

                "seatid" => descending
                    ? query.OrderByDescending(sr => sr.SeatId)
                    : query.OrderBy(sr => sr.SeatId),

                "status" => descending
                    ? query.OrderByDescending(sr => sr.Status)
                    : query.OrderBy(sr => sr.Status),

                "helduntil" => descending
                    ? query.OrderByDescending(sr => sr.HeldUntil)
                    : query.OrderBy(sr => sr.HeldUntil),

                "bookingid" => descending
                    ? query.OrderByDescending(sr => sr.BookingId)
                    : query.OrderBy(sr => sr.BookingId),

                _ => query.OrderByDescending(sr => sr.Id)
            };
        }
    }
}
