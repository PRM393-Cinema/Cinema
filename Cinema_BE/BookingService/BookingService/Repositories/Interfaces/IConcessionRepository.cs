using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IConcessionRepository
    {
        Task<List<ConcessionItem>> GetAllAsync(bool includeInactive);

        Task<ConcessionItem?> GetByIdAsync(long id);

        Task<List<ConcessionItem>> GetByIdsAsync(IEnumerable<long> ids);

        Task<List<BookingConcession>> GetByBookingIdAsync(long bookingId);

        Task AddAsync(ConcessionItem item);

        Task SaveChangesAsync();
    }
}
