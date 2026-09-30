using BookingService.Data;
using Microsoft.EntityFrameworkCore.Storage;

namespace BookingService.Helpers
{
    public class TransactionManager
    {
        private readonly BookingDbContext _context;

        public TransactionManager(BookingDbContext context)
        {
            _context = context;
        }

        public Task<IDbContextTransaction> BeginTransactionAsync()
        {
            return _context.Database.BeginTransactionAsync();
        }
    }
}
