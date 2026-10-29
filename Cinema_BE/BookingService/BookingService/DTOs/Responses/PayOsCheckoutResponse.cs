namespace BookingService.DTOs.Responses
{
    public class PayOsCheckoutResponse
    {
        public long paymentId {  get; set; }
        public long orderCode {  get; set; }
        public string? checkoutUrl { get; set; }

        // Chuỗi VietQR của link vừa tạo: khách quét bằng app ngân hàng (quầy hiện mã này).
        // Link đã có từ trước thì PayOS không trả lại, dùng checkoutUrl.
        public string? qrCode { get; set; }
    }
}
