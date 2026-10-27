namespace MovieService.Helpers
{
    // Định dạng chiếu của suất: 2D (mặc định), 3D, IMAX. 3D và IMAX cộng phụ thu vào giá ghế thường
    // của suất trước khi tính phụ thu theo loại ghế.
    public static class ShowtimeFormats
    {
        public const string TwoD = "2D";

        private static readonly Dictionary<string, decimal> Surcharges = new()
        {
            [TwoD] = 0m,
            ["3D"] = 20_000m,
            ["IMAX"] = 40_000m
        };

        public static IReadOnlyCollection<string> All => Surcharges.Keys;

        public static decimal Surcharge(string? format) =>
            Surcharges.GetValueOrDefault(Normalize(format) ?? TwoD);

        // null khi bỏ trống; sai định dạng thì null kèm cờ invalid
        public static string? Normalize(string? format) =>
            string.IsNullOrWhiteSpace(format) ? null : format.Trim().ToUpperInvariant();

        public static bool IsValid(string format) => Surcharges.ContainsKey(format);
    }
}
