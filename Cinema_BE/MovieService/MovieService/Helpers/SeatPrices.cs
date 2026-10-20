namespace MovieService.Helpers
{
    // Giá vé theo loại ghế: giá suất chiếu là giá ghế thường, ghế VIP và sweetbox cộng thêm phụ thu
    // (tính cho từng ghế, một cặp sweetbox là hai ghế). Phụ thu làm tròn tới 1.000đ.
    public static class SeatPrices
    {
        private static readonly Dictionary<string, decimal> Surcharges = new()
        {
            [SeatPairs.Normal] = 0m,
            ["VIP"] = 0.20m,
            [SeatPairs.Sweetbox] = 0.30m
        };

        public static decimal For(decimal showtimePrice, string? seatType)
        {
            var type = seatType?.Trim().ToUpperInvariant() ?? SeatPairs.Normal;
            var surcharge = Surcharges.GetValueOrDefault(type);
            return showtimePrice +
                Math.Round(showtimePrice * surcharge / 1000m, MidpointRounding.AwayFromZero) * 1000m;
        }

        // Giá từng loại ghế của suất chiếu, gửi kèm suất chiếu để app hiện đúng giá ghế khách chọn
        public static Dictionary<string, decimal> Of(decimal showtimePrice) =>
            Surcharges.Keys.ToDictionary(type => type, type => For(showtimePrice, type));
    }
}
