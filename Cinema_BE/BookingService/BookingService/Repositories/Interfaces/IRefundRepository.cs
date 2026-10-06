using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IRefundRepository
    {
        Task<Refund?> GetByIdAsync(long id);

        Task<Refund?> GetByIdForUpdateAsync(long id);

        Task<Refund?> GetByPaymentIdAsync(long paymentId);

        Task<PagedList<Refund>> GetAllAsync(string? status, int pageNumber, int pageSize);

        Task<bool> ExistsByRefundCodeAsync(string refundCode);

        Task<Refund> AddAsync(Refund refund);

        Task UpdateAsync(Refund refund);
    }
}
