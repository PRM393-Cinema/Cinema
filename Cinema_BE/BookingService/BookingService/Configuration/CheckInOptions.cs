namespace BookingService.Configuration
{
    // Check-in tại rạp (appsettings: "CheckIn"): Staff check-in vé đã thanh toán từ N phút trước
    // giờ chiếu đến M phút sau giờ chiếu, để không check-in nhầm vé của suất khác ngày / đã chiếu xong.
    public class CheckInOptions
    {
        public int OpensBeforeMinutes { get; set; } = 180;

        public int ClosesAfterMinutes { get; set; } = 120;
    }
}
