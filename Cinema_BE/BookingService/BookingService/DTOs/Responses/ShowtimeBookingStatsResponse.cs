namespace BookingService.DTOs.Responses
{
    // Vé của một suất chiếu (dashboard): số ghế đã bán, đang giữ chờ thanh toán, đã check-in
    public class ShowtimeBookingStatsResponse
    {
        public long ShowtimeId { get; set; }

        // Số đơn đặt vé còn hiệu lực (đã thanh toán, chờ hoàn tiền, đang giữ ghế)
        public int Bookings { get; set; }

        // Ghế của vé đã thanh toán (gồm vé chờ hoàn tiền)
        public int SoldSeats { get; set; }

        // Ghế đang giữ chờ thanh toán
        public int HeldSeats { get; set; }

        // Ghế của vé đã check-in (khách đã vào rạp)
        public int CheckedInSeats { get; set; }
    }
}
