using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Mapping
{
    public static class NotificationMapping
    {
        public static NotificationResponse ToResponse(
            this Notification notification)
        {
            return new NotificationResponse
            {
                Id = notification.Id,
                UserId = notification.UserId,
                BookingId = notification.BookingId,
                RecipientEmail = notification.RecipientEmail ?? string.Empty,
                Subject = notification.Subject ?? string.Empty,
                Type = notification.Type,
                Content = notification.Content ?? string.Empty,
                Status = notification.Status,
                SentAt = notification.SentAt,
                ErrorMessage = notification.ErrorMessage,
                CreatedAt = notification.CreatedAt
            };
        }
    }
}