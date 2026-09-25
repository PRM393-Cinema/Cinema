using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class BookingSeatRepository : IBookingSeatRepository
    {
        private readonly BookingDbContext _context;

        public BookingSeatRepository(BookingDbContext context)
        {
            _context = context;
        }

        //public async Task<BookingSeat?> GetByIdAsync(long id)
        //{
        //    return await _context.BookingSeats
        //        .FirstOrDefaultAsync(bs => bs.Id == id);
        //}

        //public async Task<PagedList<BookingSeat>> GetAllAsync(
        //    int pageNumber,
        //    int pageSize,
        //    string sortBy,
        //    string sortDir)
        //{
        //    IQueryable<BookingSeat> query = _context.BookingSeats;

        //    query = ApplySorting(query, sortBy, sortDir);

        //    return await PagedList<BookingSeat>.CreateAsync(
        //        query,
        //        pageNumber,
        //        pageSize);
        //}

        public async Task<List<BookingSeat>> GetByBookingIdAsync(long bookingId)
        {
            return await _context.BookingSeats
                    .Where(bs => bs.BookingId == bookingId)
                    .OrderBy(bs => bs.Id)
                    .ToListAsync();
        }

        //public async Task<BookingSeat?> GetByBookingIdAndSeatIdAsync(
        //    long bookingId,
        //    long seatId)
        //{
        //    return await _context.BookingSeats
        //        .FirstOrDefaultAsync(bs =>
        //            bs.BookingId == bookingId &&
        //            bs.SeatId == seatId);
        //}

        //public async Task<bool> ExistsAsync(
        //    long bookingId,
        //    long seatId)
        //{
        //    return await _context.BookingSeats
        //        .AnyAsync(bs =>
        //            bs.BookingId == bookingId &&
        //            bs.SeatId == seatId);
        //}

        public async Task<BookingSeat> AddAsync(
            BookingSeat bookingSeat)
        {
            _context.BookingSeats.Add(bookingSeat);

            await _context.SaveChangesAsync();

            return bookingSeat;
        }

        //public async Task DeleteAsync(
        //    BookingSeat bookingSeat)
        //{
        //    _context.BookingSeats.Remove(bookingSeat);

        //    await _context.SaveChangesAsync();
        //}

        //private static IQueryable<BookingSeat> ApplySorting(
        //    IQueryable<BookingSeat> query,
        //    string sortBy,
        //    string sortDir)
        //{
        //    bool descending = string.Equals(
        //        sortDir,
        //        "desc",
        //        StringComparison.OrdinalIgnoreCase);

        //    return sortBy?.ToLowerInvariant() switch
        //    {
        //        "id" => descending
        //            ? query.OrderByDescending(bs => bs.Id)
        //            : query.OrderBy(bs => bs.Id),

        //        "bookingid" => descending
        //            ? query.OrderByDescending(bs => bs.BookingId)
        //            : query.OrderBy(bs => bs.BookingId),

        //        "seatid" => descending
        //            ? query.OrderByDescending(bs => bs.SeatId)
        //            : query.OrderBy(bs => bs.SeatId),

        //        "seatlabel" => descending
        //            ? query.OrderByDescending(bs => bs.SeatLabel)
        //            : query.OrderBy(bs => bs.SeatLabel),

        //        "price" => descending
        //            ? query.OrderByDescending(bs => bs.Price)
        //            : query.OrderBy(bs => bs.Price),

        //        _ => query.OrderByDescending(bs => bs.Id)
        //    };
        //}
    }
}
