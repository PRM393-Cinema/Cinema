namespace BookingService.DTOs.Responses
{
    public class RefundResponse
    {
        public long Id { get; set; }

        public string RefundCode { get; set; } = null!;

        public long PaymentId { get; set; }

        public long BookingId { get; set; }

        public long UserId { get; set; }

        public decimal Amount { get; set; }

        public string Reason { get; set; } = null!;

        public string Status { get; set; } = null!;

        public string? TransactionRef { get; set; }

        public string? Note { get; set; }

        public long? ProcessedBy { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? ProcessedAt { get; set; }

        // Tài khoản khách đã chuyển tiền (nếu PayOS gửi kèm): Staff chuyển khoản hoàn tiền về đây
        public string? PayerAccountNumber { get; set; }

        public string? PayerAccountName { get; set; }

        public string? PayerBankName { get; set; }
    }
}
