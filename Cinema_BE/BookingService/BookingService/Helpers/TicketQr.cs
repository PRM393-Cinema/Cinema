using QRCoder;

namespace BookingService.Helpers
{
    // Mã QR trên vé: nội dung là mã đặt vé, Staff quét để check-in (app, trang quản trị, email vé)
    public static class TicketQr
    {
        public const string EmailContentId = "ticket-qr";

        public static byte[] Png(string bookingCode) =>
            PngByteQRCodeHelper.GetQRCode(bookingCode, QRCodeGenerator.ECCLevel.Q, 8);
    }
}
