namespace ShowtimeService.DTOs.Response
{
    // Thông tin ghế trả cho BookingService khi tạo booking (giá do server quyết định, không lấy từ client).
    public class ShowtimeSeatResponse
    {
        public long SeatId { get; set; }
        public string SeatLabel { get; set; } = null!;
        public string SeatType { get; set; } = "NORMAL";
        public decimal Price { get; set; }
    }
}
