namespace BookingService.Helpers
{
    // Hạng thành viên theo tổng chi tiêu và tỉ lệ tích điểm của từng hạng.
    // 1 điểm = 1.000đ; mỗi đơn dùng điểm tối đa 50% số tiền phải trả.
    public static class LoyaltyRules
    {
        public const decimal PointValue = 1000m;
        public const decimal MaxRedeemShare = 0.5m;

        public static readonly (string Tier, decimal MinSpend, decimal EarnRate)[] Tiers =
        [
            ("MEMBER", 0m, 0.05m),
            ("VIP", 2_000_000m, 0.07m),
            ("VVIP", 5_000_000m, 0.10m)
        ];

        public static string TierFor(decimal lifetimeSpend)
        {
            return Tiers.Last(tier => lifetimeSpend >= tier.MinSpend).Tier;
        }

        public static decimal EarnRate(string tier)
        {
            return Tiers.FirstOrDefault(t => t.Tier == tier, Tiers[0]).EarnRate;
        }

        // Hạng kế tiếp và mức chi tiêu cần đạt; null khi đã là hạng cao nhất
        public static (string Tier, decimal MinSpend)? NextTier(string tier)
        {
            var index = Array.FindIndex(Tiers, t => t.Tier == tier);
            return index >= 0 && index < Tiers.Length - 1
                ? (Tiers[index + 1].Tier, Tiers[index + 1].MinSpend)
                : null;
        }

        public static int PointsEarned(decimal paidAmount, string tier)
        {
            return (int)Math.Floor(paidAmount * EarnRate(tier) / PointValue);
        }

        public static int MaxRedeemablePoints(decimal orderAmount)
        {
            return (int)Math.Floor(orderAmount * MaxRedeemShare / PointValue);
        }
    }
}
