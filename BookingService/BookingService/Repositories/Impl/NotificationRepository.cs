using BookingService.Data;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Repositories.Impl
{
    public class NotificationRepository : INotificationRepository
    {
        private readonly NotificationDbContext _context;

        public NotificationRepository(NotificationDbContext context)
        {
            _context = context;
        }

        public async Task<PagedList<Notification>> GetAllAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            var query = ApplySorting(
                _context.Notifications.AsQueryable(),
                sortBy,
                sortDir);

            return await PagedList<Notification>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Notification?> GetByIdAsync(long id)
        {
            return await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == id);
        }

        public async Task<PagedList<Notification>> GetByUserIdAsync(
            long userId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Notification> query = _context.Notifications
                .Where(n => n.UserId == userId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Notification>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<PagedList<Notification>> GetByBookingIdAsync(
            long bookingId,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Notification> query = _context.Notifications
                .Where(n => n.BookingId == bookingId);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Notification>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Notification?> GetByEventIdAsync(
            string eventId)
        {
            return await _context.Notifications
                .FirstOrDefaultAsync(n => n.EventId == eventId);
        }

        public async Task<PagedList<Notification>> GetByStatusAsync(
            string status,
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Notification> query = _context.Notifications
                .Where(n => n.Status == status);

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Notification>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<PagedList<Notification>> GetPendingNotificationsAsync(
            int pageNumber,
            int pageSize,
            string sortBy,
            string sortDir)
        {
            IQueryable<Notification> query = _context.Notifications
                .Where(n => n.Status == "PENDING");

            query = ApplySorting(query, sortBy, sortDir);

            return await PagedList<Notification>.CreateAsync(
                query,
                pageNumber,
                pageSize);
        }

        public async Task<Notification> AddAsync(
            Notification notification)
        {
            _context.Notifications.Add(notification);

            await _context.SaveChangesAsync();

            return notification;
        }

        public async Task UpdateAsync(
            Notification notification)
        {
            _context.Notifications.Update(notification);

            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(
            Notification notification)
        {
            _context.Notifications.Remove(notification);

            await _context.SaveChangesAsync();
        }

        private static IQueryable<Notification> ApplySorting(
            IQueryable<Notification> query,
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
                    ? query.OrderByDescending(n => n.Id)
                    : query.OrderBy(n => n.Id),

                "userid" => descending
                    ? query.OrderByDescending(n => n.UserId)
                    : query.OrderBy(n => n.UserId),

                "bookingid" => descending
                    ? query.OrderByDescending(n => n.BookingId)
                    : query.OrderBy(n => n.BookingId),

                "type" => descending
                    ? query.OrderByDescending(n => n.Type)
                    : query.OrderBy(n => n.Type),

                "status" => descending
                    ? query.OrderByDescending(n => n.Status)
                    : query.OrderBy(n => n.Status),

                "createdat" => descending
                    ? query.OrderByDescending(n => n.CreatedAt)
                    : query.OrderBy(n => n.CreatedAt),

                "sentat" => descending
                    ? query.OrderByDescending(n => n.SentAt)
                    : query.OrderBy(n => n.SentAt),

                _ => query.OrderByDescending(n => n.CreatedAt)
            };
        }
    }
}
