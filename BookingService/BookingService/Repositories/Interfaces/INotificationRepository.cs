using BookingService.Helpers;
using BookingService.Models;

namespace BookingService.Repositories.Interfaces
{
    public interface INotificationRepository
    {
        Task<PagedList<Notification>> GetAllAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir);

        Task<Notification?> GetByIdAsync(long id);

        Task<PagedList<Notification>> GetByUserIdAsync(long userId, int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<PagedList<Notification>> GetByBookingIdAsync(long bookingId, int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<Notification?> GetByEventIdAsync(string eventId);

        Task<PagedList<Notification>> GetByStatusAsync(string status, int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<PagedList<Notification>> GetPendingNotificationsAsync(int pageNumber, int pageSize, string sortBy, string sortDir);

        Task<Notification> AddAsync(Notification notification);

        Task UpdateAsync(Notification notification);

        Task DeleteAsync(Notification notification);
    }
}
