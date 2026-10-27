namespace BookingService.DTOs.Responses
{
    public class BookingResponse
    {
        public long Id { get; set; }

        public string BookingCode { get; set; } = null!;

        // null: khách vãng lai (vé bán tại quầy, không có tài khoản)
        public long? UserId { get; set; }

        public string? CustomerEmail { get; set; }

        public string? CustomerPhone { get; set; }

        public long ShowtimeId { get; set; }

        public string Status { get; set; } = null!;

        public decimal TotalAmount { get; set; }

        public long? PaymentId { get; set; }

        public string? MovieTitle { get; set; }

        public DateTime? ShowTime { get; set; }

        public DateTime? ExpiresAt { get; set; }

        public DateTime? CheckedInAt { get; set; }

        public DateTime CreatedAt { get; set; }

        public List<BookingSeatResponse> Seats { get; set; } = new();

        // Tiền bắp nước, đã tính trong TotalAmount
        public decimal ConcessionsAmount { get; set; }

        // Tiền vé được giảm nhờ khuyến mãi, đã trừ trong TotalAmount
        public decimal DiscountAmount { get; set; }

        public string? PromotionCode { get; set; }

        public string? PromotionName { get; set; }

        public List<BookingConcessionResponse> Concessions { get; set; } = new();
    }
}
