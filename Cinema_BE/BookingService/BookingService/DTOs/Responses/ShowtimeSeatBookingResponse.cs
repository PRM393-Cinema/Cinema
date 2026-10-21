namespace BookingService.DTOs.Responses
{
    // Ghế đã có người đặt / đang giữ của một suất chiếu, kèm vé đang giữ ghế đó (cho Staff xem sơ đồ phòng)
    public class ShowtimeSeatBookingResponse
    {
        public long SeatId { get; set; }

        public string SeatLabel { get; set; } = null!;

        public long BookingId { get; set; }

        public string BookingCode { get; set; } = null!;

        public long UserId { get; set; }

        public string? CustomerEmail { get; set; }

        public string Status { get; set; } = null!;

        public DateTime? CheckedInAt { get; set; }
    }
}
