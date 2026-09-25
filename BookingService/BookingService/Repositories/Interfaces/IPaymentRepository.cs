using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface IPaymentRepository
    {
        Task<PagedList<Payment>> GetAllAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);

        Task<Payment?> GetByIdAsync(long id);

        Task<Payment?> GetByPaymentCodeAsync(string paymentCode);

        Task<PagedList<Payment>> GetByBookingIdAsync(
            long bookingId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);

        Task<PagedList<Payment>> GetByUserIdAsync(long userId, int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<Payment?> GetByTransactionRefAsync(string transactionRef);

        Task<PagedList<Payment>> GetByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<bool> ExistsByPaymentCodeAsync(string paymentCode);

        Task<Payment> AddAsync(Payment payment);

        Task UpdateAsync(Payment payment);

        Task DeleteAsync(Payment payment);
    }
}
