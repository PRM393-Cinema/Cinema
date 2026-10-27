namespace BookingService.Configuration
{
    // Job nhắc giờ chiếu: vé đã thanh toán, chưa check-in, giờ chiếu trong BeforeMinutes phút tới
    public class ShowtimeReminderOptions
    {
        public bool Enabled { get; set; } = true;

        public int BeforeMinutes { get; set; } = 120;

        public int IntervalSeconds { get; set; } = 60;

        public int BatchSize { get; set; } = 100;
    }
}
