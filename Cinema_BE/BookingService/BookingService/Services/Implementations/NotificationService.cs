using BookingService.Clients.Interfaces;
using BookingService.DTOs;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;
using BookingService.Validators;

namespace BookingService.Services.Implementations
{
    public sealed class NotificationService : INotificationService
    {
        private readonly INotificationRepository _notificationRepository;
        private readonly IEmailSender _emailSender;
        private readonly ILogger<NotificationService> _logger;

        public NotificationService(
            INotificationRepository notificationRepository,
            IEmailSender emailSender,
            ILogger<NotificationService> logger)
        {
            _notificationRepository = notificationRepository;
            _emailSender = emailSender;
            _logger = logger;
        }

        public async Task<PagedResult<NotificationResponse>> GetAllNotificationsAsync(
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var notifications = await _notificationRepository
                .GetAllAsync(page, size, sortBy, sortDir);

            return ToPagedResult(notifications);
        }

        public async Task<PagedResult<NotificationResponse>> GetNotificationsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var notifications = await _notificationRepository
                .GetByUserIdAsync(userId, page, size, sortBy, sortDir);

            return ToPagedResult(notifications);
        }

        public async Task<NotificationResponse> GetNotificationByIdAsync(long id)
        {
            var notification = await GetNotificationAsync(id);
            return notification.ToResponse();
        }

        public async Task<NotificationResponse> CreateNotificationAsync(
            NotificationRequest request)
        {
            NotificationValidator.Validate(request);

            var notification = await _notificationRepository.AddAsync(
                new Notification
                {
                    UserId = request.UserId!.Value,
                    BookingId = request.BookingId,
                    RecipientEmail = request.RecipientEmail!.Trim(),
                    Subject = request.Subject!.Trim(),
                    Type = request.Type!.Trim().ToUpperInvariant(),
                    Content = request.Content,
                    Status = "PENDING",
                    CreatedAt = DateTime.Now
                });

            return notification.ToResponse();
        }

        public async Task CreateNotificationFromEventAsync(
            string eventId,
            NotificationRequest request)
        {
            ValidateEventId(eventId);
            NotificationValidator.Validate(request);

            var existing = await _notificationRepository
                .GetByEventIdAsync(eventId);

            if (existing != null)
            {
                return;
            }

            await _notificationRepository.AddAsync(
                new Notification
                {
                    UserId = request.UserId!.Value,
                    BookingId = request.BookingId,
                    RecipientEmail = request.RecipientEmail!.Trim(),
                    Subject = request.Subject!.Trim(),
                    Type = request.Type!.Trim().ToUpperInvariant(),
                    Content = request.Content,
                    Status = "PENDING",
                    EventId = eventId,
                    CreatedAt = DateTime.Now
                });
        }

        public async Task SendNotificationFromEventAsync(
            string eventId,
            long userId,
            long? bookingId,
            string type,
            EmailMessage email)
        {
            ValidateEventId(eventId);
            NotificationValidator.ValidateEmail(email);

            var notification = await _notificationRepository
                .GetByEventIdAsync(eventId);

            if (notification?.Status == "SENT")
            {
                return;
            }

            if (notification == null)
            {
                notification = new Notification
                {
                    UserId = userId,
                    BookingId = bookingId,
                    Type = type.Trim().ToUpperInvariant(),
                    Subject = email.Subject,
                    Content = email.Content,
                    RecipientEmail = email.RecipientEmail.Trim(),
                    Status = "PENDING",
                    EventId = eventId,
                    CreatedAt = DateTime.Now
                };

                notification = await _notificationRepository.AddAsync(
                    notification);
            }
            else
            {
                notification.Status = "PENDING";
                notification.ErrorMessage = null;
                await _notificationRepository.UpdateAsync(notification);
            }

            await SendEmailAsync(notification, email);
        }

        private async Task SendEmailAsync(Notification notification, EmailMessage email)
        {
            NotificationValidator.ValidateEmail(email);
            try
            {
                await _emailSender.SendAsync(email);

                notification.Status = "SENT";
                notification.SentAt = DateTime.Now;
                notification.ErrorMessage = null;
                await _notificationRepository.UpdateAsync(notification);
            }
            catch (Exception exception)
            {
                notification.Status = "FAILED";
                notification.ErrorMessage = TrimError(exception.Message);

                try
                {
                    await _notificationRepository.UpdateAsync(notification);
                }
                catch (Exception persistenceException)
                {
                    _logger.LogError(
                        persistenceException,
                        "Could not persist failed notification {NotificationId}.",
                        notification.Id);
                }

                throw new ExternalServiceException(
                    "Notification email could not be sent.");
            }
        }

        public async Task<NotificationResponse> SendNotificationAsync(long id)
        {
            var notification = await GetNotificationAsync(id);

            if (notification.Status == "SENT")
            {
                return notification.ToResponse();
            }

            if (notification.EventId == null)
            {
                // Older manual sends created a separate SENT row; do not email again.
                var previousSend = await _notificationRepository.GetByEventIdAsync($"NOTIFICATION:{notification.Id}");
                if (previousSend?.Status == "SENT")
                {
                    notification.Status = "SENT";
                    notification.SentAt = previousSend.SentAt;
                    notification.ErrorMessage = null;
                    await _notificationRepository.UpdateAsync(notification);
                    return notification.ToResponse();
                }
            }

            await SendEmailAsync(
                notification,
                new EmailMessage
                {
                    RecipientEmail = notification.RecipientEmail ?? string.Empty,
                    Subject = notification.Subject ?? string.Empty,
                    Content = notification.Content ?? string.Empty
                });

            return (await GetNotificationAsync(notification.Id)).ToResponse();
        }

        public async Task DeleteNotificationAsync(long id)
        {
            var notification = await GetNotificationAsync(id);
            await _notificationRepository.DeleteAsync(notification);
        }

        private async Task<Notification> GetNotificationAsync(long id)
        {
            var notification = await _notificationRepository.GetByIdAsync(id);

            if (notification == null)
            {
                throw new KeyNotFoundException(
                    $"Notification with id {id} was not found.");
            }

            return notification;
        }

        private static PagedResult<NotificationResponse> ToPagedResult(
            PagedList<Notification> notifications)
        {
            return new PagedResult<NotificationResponse>
            {
                Items = notifications
                    .Select(notification => notification.ToResponse())
                    .ToList(),
                PageNumber = notifications.PageNumber,
                PageSize = notifications.PageSize,
                TotalPages = notifications.TotalPages,
                TotalCount = notifications.TotalCount
            };
        }

        private static void ValidateEventId(string eventId)
        {
            if (string.IsNullOrWhiteSpace(eventId) || eventId.Length > 36)
            {
                throw new BusinessException(
                    "Event id is required and must not exceed 36 characters.");
            }
        }

        private static string TrimError(string message)
        {
            return message.Length <= 1000
                ? message
                : message[..1000];
        }
    }
}
