namespace ShowtimeService.DTOs.Response
{
    public class ShowtimeResponse
    {
        public long Id { get; set; }
        public long MovieId { get; set; }
        public long RoomId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        // Giá ghế thường
        public decimal Price { get; set; }
        // Giá một ghế theo loại: NORMAL, VIP, SWEETBOX
        public Dictionary<string, decimal> SeatPrices { get; set; } = new();
        public string Status { get; set; } = null!;
    }
}
