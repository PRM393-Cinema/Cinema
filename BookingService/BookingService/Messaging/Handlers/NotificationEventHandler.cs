using BookingService.DTOs;
using BookingService.Exceptions;
using BookingService.Services.Interfaces;

namespace BookingService.Messaging.Handlers
{
    // FR-NOTI-06: nhận event booking.* / payment.* và gửi email cho khách.
    // Idempotent: notification lưu theo eventId (unique), message giao lại không gửi email lần hai.
    public sealed class NotificationEventHandler : IIntegrationEventHandler
    {
        private readonly INotificationService _notificationService;
        private readonly ILogger<NotificationEventHandler> _logger;

        public NotificationEventHandler(
            INotificationService notificationService,
            ILogger<NotificationEventHandler> logger)
        {
            _notificationService = notificationService;
            _logger = logger;
        }

        public Task HandleAsync(IntegrationEvent integrationEvent, CancellationToken cancellationToken)
        {
            switch (integrationEvent.EventType)
            {
                case EventTypes.BookingConfirmed:
                {
                    var data = integrationEvent.GetData<BookingEventData>();
                    return SendAsync(integrationEvent, data.UserId, data.BookingId, "BOOKING_CONFIRMED",
                        data.RecipientEmail ?? data.CustomerEmail,
                        email => EmailTemplates.BookingConfirmed(data, email));
                }
                case EventTypes.BookingCancelled:
                {
                    var data = integrationEvent.GetData<BookingEventData>();
                    return SendAsync(integrationEvent, data.UserId, data.BookingId, "BOOKING_CANCELLED",
                        data.CustomerEmail,
                        email => EmailTemplates.BookingCancelled(data, email));
                }
                case EventTypes.BookingExpired:
                {
                    var data = integrationEvent.GetData<BookingEventData>();
                    return SendAsync(integrationEvent, data.UserId, data.BookingId, "BOOKING_EXPIRED",
                        data.CustomerEmail,
                        email => EmailTemplates.BookingExpired(data, email));
                }
                case EventTypes.PaymentRefundRequested:
                {
                    var data = integrationEvent.GetData<PaymentEventData>();
                    return SendAsync(integrationEvent, data.UserId, data.BookingId, "REFUND_REQUESTED",
                        data.CustomerEmail,
                        email => EmailTemplates.RefundRequested(data, email));
                }
                case EventTypes.PaymentRefunded:
                {
                    var data = integrationEvent.GetData<PaymentEventData>();
                    return SendAsync(integrationEvent, data.UserId, data.BookingId, "REFUND_COMPLETED",
                        data.CustomerEmail,
                        email => EmailTemplates.RefundCompleted(data, email));
                }
                default:
                    // booking.created, payment.created... không cần báo cho khách
                    return Task.CompletedTask;
            }
        }

        private async Task SendAsync(
            IntegrationEvent integrationEvent,
            long userId,
            long? bookingId,
            string type,
            string? recipientEmail,
            Func<string, EmailMessage> buildEmail)
        {
            if (string.IsNullOrWhiteSpace(recipientEmail))
            {
                _logger.LogWarning(
                    "{EventType} {EventId} has no customer email, notification was not sent.",
                    integrationEvent.EventType,
                    integrationEvent.EventId);
                return;
            }

            try
            {
                await _notificationService.SendNotificationFromEventAsync(
                    integrationEvent.EventId,
                    userId,
                    bookingId,
                    type,
                    buildEmail(recipientEmail));
            }
            // SMTP lỗi: notification đã được lưu FAILED kèm lỗi, Staff gửi lại bằng POST /notifications/{id}/send
            catch (ExternalServiceException ex)
            {
                _logger.LogWarning(
                    "Email for {EventType} {EventId} could not be sent: {Reason}",
                    integrationEvent.EventType,
                    integrationEvent.EventId,
                    ex.Message);
            }
        }
    }
}
