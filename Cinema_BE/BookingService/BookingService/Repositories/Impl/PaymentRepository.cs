using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class PaymentRepository : IPaymentRepository
    {
        private readonly PaymentDbContext _context;

        public PaymentRepository(PaymentDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Payment>> GetAllAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var query = ApplySorting(
                _context.Payments.AsQueryable(),
                sortBy,
                sortDir);

            return await PagedList<Payment>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Payment?> GetByIdAsync(long id)
        {
            return await _context.Payments
                .FirstOrDefaultAsync(p => p.Id == id);
        }

        // FOR UPDATE: khoá dòng payment tới hết transaction
        public async Task<Payment?> GetByIdForUpdateAsync(long id)
        {
            return await _context.Payments
                .FromSqlInterpolated($@"
            SELECT *
            FROM payments
            WHERE id = {id}
            FOR UPDATE")
                .AsTracking()
                .FirstOrDefaultAsync();
        }

        public async Task<List<Payment>> GetByIdsAsync(List<long> ids)
        {
            return await _context.Payments
                .Where(p => ids.Contains(p.Id))
                .ToListAsync();
        }

        public async Task<Payment?> GetLatestByBookingIdAsync(
            long bookingId,
            params string[] statuses)
        {
            return await _context.Payments
                .Where(p => p.BookingId == bookingId && statuses.Contains(p.Status))
                .OrderByDescending(p => p.Id)
                .FirstOrDefaultAsync();
        }

        public async Task<Payment?> GetByPaymentCodeAsync(
            string paymentCode)
        {
            return await _context.Payments
                .FirstOrDefaultAsync(p =>
                    p.PaymentCode == paymentCode);
        }

        public async Task<PagedList<Payment>> GetByBookingIdAsync(
            long bookingId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Payment> query = _context.Payments
                .Where(p => p.BookingId == bookingId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Payment>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<PagedList<Payment>> GetByUserIdAsync(
            long userId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Payment> query = _context.Payments
                .Where(p => p.UserId == userId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Payment>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Payment?> GetByTransactionRefAsync(
            string transactionRef)
        {
            return await _context.Payments
                .FirstOrDefaultAsync(p =>
                    p.TransactionRef == transactionRef);
        }

        public async Task<PagedList<Payment>> GetByStatusAsync(
            string status,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Payment> query = _context.Payments
                .Where(p => p.Status == status);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Payment>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<bool> ExistsByPaymentCodeAsync(
            string paymentCode)
        {
            return await _context.Payments
                .AnyAsync(p =>
                    p.PaymentCode == paymentCode);
        }

        public async Task<Payment> AddAsync(
            Payment payment)
        {
            _context.Payments.Add(payment);

            await _context.SaveChangesAsync();

            return payment;
        }

        public async Task UpdateAsync(
            Payment payment)
        {
            _context.Payments.Update(payment);

            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(
            Payment payment)
        {
            _context.Payments.Remove(payment);

            await _context.SaveChangesAsync();
        }

        private static IQueryable<Payment> ApplySorting(
            IQueryable<Payment> query,
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
                    ? query.OrderByDescending(p => p.Id)
                    : query.OrderBy(p => p.Id),

                "paymentcode" => descending
                    ? query.OrderByDescending(p => p.PaymentCode)
                    : query.OrderBy(p => p.PaymentCode),

                "bookingid" => descending
                    ? query.OrderByDescending(p => p.BookingId)
                    : query.OrderBy(p => p.BookingId),

                "userid" => descending
                    ? query.OrderByDescending(p => p.UserId)
                    : query.OrderBy(p => p.UserId),

                "amount" => descending
                    ? query.OrderByDescending(p => p.Amount)
                    : query.OrderBy(p => p.Amount),

                "method" => descending
                    ? query.OrderByDescending(p => p.Method)
                    : query.OrderBy(p => p.Method),

                "status" => descending
                    ? query.OrderByDescending(p => p.Status)
                    : query.OrderBy(p => p.Status),

                "createdat" => descending
                    ? query.OrderByDescending(p => p.CreatedAt)
                    : query.OrderBy(p => p.CreatedAt),

                "updatedat" => descending
                    ? query.OrderByDescending(p => p.UpdatedAt)
                    : query.OrderBy(p => p.UpdatedAt),

                _ => query.OrderByDescending(p => p.CreatedAt)
            };
        }
    }
}
