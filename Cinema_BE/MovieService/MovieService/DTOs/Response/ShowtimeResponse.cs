namespace ShowtimeService.DTOs.Response
{
    public class ShowtimeResponse
    {
        public long Id { get; set; }
        public long MovieId { get; set; }
        public long RoomId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        // Giá ghế thường của suất 2D (chưa gồm phụ thu định dạng)
        public decimal Price { get; set; }
        // 2D / 3D / IMAX và phụ thu cộng vào giá ghế thường (đã tính trong SeatPrices)
        public string Format { get; set; } = "2D";
        public decimal FormatSurcharge { get; set; }
        // Giá một ghế theo loại: NORMAL, VIP, SWEETBOX
        public Dictionary<string, decimal> SeatPrices { get; set; } = new();
        public string Status { get; set; } = null!;
    }
}
