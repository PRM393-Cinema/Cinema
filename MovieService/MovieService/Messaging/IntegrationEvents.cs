using System.Text.Json;

namespace MovieService.Messaging
{
    // Event MovieService phát lên RabbitMQ (SRS §13.1). Routing key = tên event.
    public static class EventTypes
    {
        // BookingService nhận để huỷ các booking của suất chiếu và hoàn tiền
        public const string ShowtimeCancelled = "showtime.cancelled";
    }

    public static class MessagingJson
    {
        public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
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
