using BookingService.DTOs;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using System.Net.Mail;

namespace BookingService.Services.Interfaces
{
    public interface INotificationService
    {
        Task<PagedResult<NotificationResponse>> GetAllNotificationsAsync(
        int page,
        int size,
        string sortBy,
        string sortDir);

        Task<PagedResult<NotificationResponse>> GetNotificationsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir);

        Task<NotificationResponse> GetNotificationByIdAsync(
            long id);

        Task<NotificationResponse> CreateNotificationAsync(
            NotificationRequest request);

        Task CreateNotificationFromEventAsync(
            string eventId,
            NotificationRequest request);

        Task SendNotificationFromEventAsync(
            string eventId,
            long userId,
            long? bookingId,
            string type,
            EmailMessage email);

        Task<NotificationResponse> SendNotificationAsync(long id);

        Task DeleteNotificationAsync(long id);
    }
}
