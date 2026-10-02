using System.Text.Json;

namespace BookingService.Messaging
{
    // Event nghiệp vụ trao đổi qua RabbitMQ (SRS §13.1). Routing key = tên event.
    public static class EventTypes
    {
        public const string BookingCreated = "booking.created";
        public const string BookingConfirmed = "booking.confirmed";
        public const string BookingCancelled = "booking.cancelled";
        public const string BookingExpired = "booking.expired";
        public const string PaymentCreated = "payment.created";
        public const string PaymentSucceeded = "payment.succeeded";
        public const string PaymentFailed = "payment.failed";
        public const string PaymentRefundRequested = "payment.refund_requested";
        public const string PaymentRefunded = "payment.refunded";

        // Do MovieService phát khi huỷ suất chiếu
        public const string ShowtimeCancelled = "showtime.cancelled";
    }

    public static class MessagingJson
    {
        public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    }

    // Phong bì của mọi message: { eventId, eventType, occurredAt, data }
    public sealed class IntegrationEvent
    {
        public string EventId { get; set; } = string.Empty;

        public string EventType { get; set; } = string.Empty;

        public DateTime OccurredAt { get; set; }

        public JsonElement Data { get; set; }

        public T GetData<T>()
        {
            return Data.Deserialize<T>(MessagingJson.Options)
                ?? throw new JsonException($"Event {EventId} has no data.");
        }
    }

    public sealed class BookingEventData
    {
        public long BookingId { get; set; }

        public string BookingCode { get; set; } = string.Empty;

        public long UserId { get; set; }

        public string? CustomerEmail { get; set; }

        // Email nhận vé do Staff chỉ định khi xác nhận tại quầy (không có thì dùng CustomerEmail)
        public string? RecipientEmail { get; set; }

        public long ShowtimeId { get; set; }

        public string? MovieTitle { get; set; }

        public DateTime? ShowTime { get; set; }

        public List<string> Seats { get; set; } = new();

        public decimal TotalAmount { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? PreviousStatus { get; set; }

        public long? PaymentId { get; set; }

        public DateTime? ExpiresAt { get; set; }

        public string? Reason { get; set; }

        // CUSTOMER / STAFF / SYSTEM
        public string? CancelledBy { get; set; }
    }

    public sealed class PaymentEventData
    {
        public long PaymentId { get; set; }

        public string PaymentCode { get; set; } = string.Empty;

        public long BookingId { get; set; }

        public string? BookingCode { get; set; }

        public long UserId { get; set; }

        public string? CustomerEmail { get; set; }

        public string? MovieTitle { get; set; }

        public DateTime? ShowTime { get; set; }

        public decimal Amount { get; set; }

        public string? Method { get; set; }

        public string Status { get; set; } = string.Empty;

        public long? RefundId { get; set; }

        public string? RefundCode { get; set; }

        public decimal? RefundAmount { get; set; }

        public string? RefundTransactionRef { get; set; }

        public string? Reason { get; set; }
    }

    public sealed class ShowtimeCancelledEventData
    {
        public long ShowtimeId { get; set; }

        public long MovieId { get; set; }

        public long RoomId { get; set; }

        public DateTime StartTime { get; set; }

        public DateTime EndTime { get; set; }
    }
}
