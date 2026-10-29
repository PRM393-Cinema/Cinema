namespace BookingService.DTOs.Responses
{
    // Thẻ thành viên: điểm, hạng, tỉ lệ tích điểm và mức chi tiêu để lên hạng
    public class LoyaltyAccountResponse
    {
        public long UserId { get; set; }

        public int Points { get; set; }

        public decimal PointValue { get; set; }

        public string Tier { get; set; } = "MEMBER";

        public decimal LifetimeSpend { get; set; }

        public decimal EarnRatePercent { get; set; }

        public string? NextTier { get; set; }

        public decimal? NextTierSpend { get; set; }
    }

    public class LoyaltyResponse : LoyaltyAccountResponse
    {
        public BookingService.Models.MemberGift? Gifts { get; set; }
        // Mới nhất trước, tối đa 50 dòng
        public List<LoyaltyTransactionResponse> Transactions { get; set; } = new();
    }

    public class LoyaltyTransactionResponse
    {
        public long Id { get; set; }

        public string Type { get; set; } = string.Empty;

        public int Points { get; set; }

        public long? BookingId { get; set; }

        public string? Note { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
