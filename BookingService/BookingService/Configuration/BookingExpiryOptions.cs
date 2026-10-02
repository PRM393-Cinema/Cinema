namespace BookingService.Configuration
{
    // Job tự hết hạn booking PENDING quá thời gian giữ ghế (appsettings: "BookingExpiry")
    public class BookingExpiryOptions
    {
        public bool Enabled { get; set; } = true;

        public int IntervalSeconds { get; set; } = 30;

        public int BatchSize { get; set; } = 100;
    }
}
