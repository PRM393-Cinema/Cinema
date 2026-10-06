namespace BookingService.DTOs.Responses
{
    public class BookingResponse
    {
        public long Id { get; set; }

        public string BookingCode { get; set; } = null!;

        public long UserId { get; set; }

        public string? CustomerEmail { get; set; }

        public long ShowtimeId { get; set; }

        public string Status { get; set; } = null!;

        public decimal TotalAmount { get; set; }

        public long? PaymentId { get; set; }

        public string? MovieTitle { get; set; }

        public DateTime? ShowTime { get; set; }

        public DateTime? ExpiresAt { get; set; }

        public DateTime CreatedAt { get; set; }

        public List<BookingSeatResponse> Seats { get; set; } = new();
    }
}
