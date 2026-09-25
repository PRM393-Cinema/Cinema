namespace BookingService.DTOs.Responses
{
    public class NotificationResponse
    {
        public long Id { get; set; }

        public long UserId { get; set; }

        public long? BookingId { get; set; }

        public string RecipientEmail { get; set; } = null!;

        public string Subject { get; set; } = null!;

        public string Type { get; set; } = null!;

        public string Content { get; set; } = null!;

        public string Status { get; set; } = null!;

        public DateTime? SentAt { get; set; }

        public string? ErrorMessage { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
