namespace BookingService.DTOs.Responses
{
    public class PromotionResponse
    {
        public long Id { get; set; }

        public string? Code { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public string DiscountType { get; set; } = string.Empty;

        public decimal DiscountValue { get; set; }

        public decimal? MaxDiscount { get; set; }

        public int MinTickets { get; set; }

        public List<int> DaysOfWeek { get; set; } = new();

        public DateTime? StartsAt { get; set; }

        public DateTime? EndsAt { get; set; }

        public int? UsageLimit { get; set; }

        public int UsedCount { get; set; }

        public bool Active { get; set; }
    }

    // Khuyến mãi được áp cho các vé đang chọn; Discount = 0 khi không có
    public class PromotionQuoteResponse
    {
        public long? PromotionId { get; set; }

        public string? Code { get; set; }

        public string? Name { get; set; }

        public string? Description { get; set; }

        public decimal Discount { get; set; }
    }
}
