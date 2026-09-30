namespace BookingService.DTOs.Responses
{
    public class PaymentResponse
    {
        public long Id { get; set; }

        public string PaymentCode { get; set; } = null!;

        public long BookingId { get; set; }

        public long UserId { get; set; }

        public string RecipientEmail { get; set; } = null!;

        public decimal Amount { get; set; }

        public string? Method { get; set; }

        public string Status { get; set; } = null!;

        public string? TransactionRef { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }
}
