namespace BookingService.Configuration
{
    // Chính sách huỷ vé đã thanh toán (appsettings: "RefundPolicy").
    // Khách tự huỷ khi còn ít nhất N giờ trước giờ chiếu, hoàn 100%. Staff/Admin huỷ được mọi lúc.
    public class RefundPolicyOptions
    {
        public int CustomerCancelBeforeHours { get; set; } = 2;
    }
}
