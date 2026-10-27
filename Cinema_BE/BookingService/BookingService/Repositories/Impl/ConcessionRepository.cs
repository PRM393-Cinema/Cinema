using BookingService.Data;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class ConcessionRepository : IConcessionRepository
    {
        private readonly BookingDbContext _context;

        public ConcessionRepository(BookingDbContext context)
        {
            _context = context;
        }

        public async Task<List<ConcessionItem>> GetAllAsync(bool includeInactive)
        {
            return await _context.ConcessionItems
                .AsNoTracking()
                .Where(item => includeInactive || item.Active)
                .OrderBy(item => item.SortOrder)
                .ThenBy(item => item.Id)
                .ToListAsync();
        }

        public async Task<ConcessionItem?> GetByIdAsync(long id)
        {
            return await _context.ConcessionItems.FirstOrDefaultAsync(item => item.Id == id);
        }

        public async Task<List<ConcessionItem>> GetByIdsAsync(IEnumerable<long> ids)
        {
            var list = ids.ToList();
            return await _context.ConcessionItems
                .AsNoTracking()
                .Where(item => list.Contains(item.Id))
                .ToListAsync();
        }

        public async Task<List<BookingConcession>> GetByBookingIdAsync(long bookingId)
        {
            return await _context.BookingConcessions
                .AsNoTracking()
                .Where(item => item.BookingId == bookingId)
                .OrderBy(item => item.Id)
                .ToListAsync();
        }

        public async Task AddAsync(ConcessionItem item)
        {
            await _context.ConcessionItems.AddAsync(item);
        }

        public async Task SaveChangesAsync()
        {
            await _context.SaveChangesAsync();
        }
    }
}
