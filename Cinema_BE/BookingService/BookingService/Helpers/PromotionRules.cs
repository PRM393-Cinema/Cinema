using BookingService.Models;

namespace BookingService.Helpers
{
    // Điều kiện và số tiền giảm của một khuyến mãi. Chỉ giảm tiền vé (không giảm bắp nước),
    // tối đa 90% tiền vé để đơn luôn còn tiền phải trả, làm tròn xuống tới 1.000đ.
    public static class PromotionRules
    {
        public const decimal MaxShareOfTickets = 0.9m;

        private static readonly string[] DayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

        // null khi áp dụng được, ngược lại là lý do
        public static string? WhyNot(Promotion promotion, int tickets, DateTime showStart, DateTime now)
        {
            if (!promotion.Active || promotion.EndsAt < now)
            {
                return "This promotion has ended.";
            }

            if (promotion.StartsAt > now)
            {
                return $"This promotion starts on {promotion.StartsAt:dd/MM/yyyy}.";
            }

            if (promotion.UsageLimit.HasValue && promotion.UsedCount >= promotion.UsageLimit.Value)
            {
                return "This promotion has been fully used.";
            }

            if (tickets < promotion.MinTickets)
            {
                return $"This promotion needs at least {promotion.MinTickets} tickets.";
            }

            var days = ParseDays(promotion.DaysOfWeek);
            if (days.Count > 0 && !days.Contains(IsoDay(showStart)))
            {
                return $"This promotion is only for shows on {string.Join(", ", days.Select(day => DayNames[day - 1]))}.";
            }

            return null;
        }

        public static decimal Discount(Promotion promotion, decimal ticketAmount)
        {
            var discount = promotion.DiscountType == "PERCENT"
                ? ticketAmount * promotion.DiscountValue / 100m
                : promotion.DiscountValue;

            if (promotion.MaxDiscount is > 0)
            {
                discount = Math.Min(discount, promotion.MaxDiscount.Value);
            }

            discount = Math.Min(discount, ticketAmount * MaxShareOfTickets);
            return Math.Floor(discount / 1000m) * 1000m;
        }

        public static List<int> ParseDays(string? days)
        {
            return string.IsNullOrWhiteSpace(days)
                ? new List<int>()
                : days.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Select(int.Parse)
                    .Distinct()
                    .OrderBy(day => day)
                    .ToList();
        }

        // 1 = thứ Hai ... 7 = Chủ nhật
        public static int IsoDay(DateTime date)
        {
            return ((int)date.DayOfWeek + 6) % 7 + 1;
        }
    }
}
