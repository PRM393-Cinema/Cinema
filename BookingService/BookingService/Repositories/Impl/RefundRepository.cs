using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class RefundRepository : IRefundRepository
    {
        private readonly PaymentDbContext _context;

        public RefundRepository(PaymentDbContext context)
        {
            _context = context;
        }

        public async Task<Refund?> GetByIdAsync(long id)
        {
            return await _context.Refunds
                .FirstOrDefaultAsync(r => r.Id == id);
        }

        public async Task<Refund?> GetByIdForUpdateAsync(long id)
        {
            return await _context.Refunds
                .FromSqlInterpolated($@"
            SELECT *
            FROM refunds
            WHERE id = {id}
            FOR UPDATE")
                .AsTracking()
                .FirstOrDefaultAsync();
        }

        public async Task<Refund?> GetByPaymentIdAsync(long paymentId)
        {
            return await _context.Refunds
                .FirstOrDefaultAsync(r => r.PaymentId == paymentId);
        }

        // Lọc PENDING: yêu cầu cũ nhất lên đầu để Staff xử lý theo thứ tự. Còn lại: mới nhất lên đầu
        public async Task<PagedList<Refund>> GetAllAsync(
            string? status,
            int pageNumber,
            int pageSize)
        {
            IQueryable<Refund> query = _context.Refunds;
            var normalized = status?.Trim().ToUpperInvariant();

            if (!string.IsNullOrEmpty(normalized))
            {
                query = query.Where(r => r.Status == normalized);
            }

            query = normalized == "PENDING"
                ? query.OrderBy(r => r.CreatedAt)
                : query.OrderByDescending(r => r.CreatedAt);

            return await PagedList<Refund>.CreateAsync(query, pageNumber, pageSize);
        }

        public async Task<bool> ExistsByRefundCodeAsync(string refundCode)
        {
            return await _context.Refunds
                .AnyAsync(r => r.RefundCode == refundCode);
        }

        public async Task<Refund> AddAsync(Refund refund)
        {
            _context.Refunds.Add(refund);

            await _context.SaveChangesAsync();

            return refund;
        }

        public async Task UpdateAsync(Refund refund)
        {
            _context.Refunds.Update(refund);

            await _context.SaveChangesAsync();
        }
    }
}
