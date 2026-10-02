using System.Text.Encodings.Web;
using BookingService.DTOs;

namespace BookingService.Messaging.Handlers
{
    // Nội dung email gửi cho khách theo từng event (HTML, mọi dữ liệu đều được encode)
    public static class EmailTemplates
    {
        private static readonly HtmlEncoder Encoder = HtmlEncoder.Default;

        public static EmailMessage BookingConfirmed(BookingEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Đặt vé thành công</h2>
                <p>Đơn đặt vé <strong>{E(data.BookingCode)}</strong> của bạn đã được xác nhận.</p>
                {BookingDetails(data)}
                <div style="background:#fff3cd;border:1px solid #ffecb5;padding:12px;margin:16px 0;color:#664d03">
                  <strong>ĐẶC BIỆT LƯU Ý:</strong> Vui lòng có mặt trước giờ chiếu ít nhất 15 phút và xuất trình mã đặt vé khi đến rạp.
                </div>
                """;

            return Build(recipientEmail, $"Xác nhận đặt vé {data.BookingCode}", body);
        }

        public static EmailMessage BookingCancelled(BookingEventData data, string recipientEmail)
        {
            var paid = data.PreviousStatus == "CONFIRMED" && data.PaymentId.HasValue;

            var body = $"""
                <h2>Đơn đặt vé đã được huỷ</h2>
                <p>Đơn đặt vé <strong>{E(data.BookingCode)}</strong> đã được huỷ{Reason(data.Reason)}.</p>
                {BookingDetails(data)}
                <p>{(paid
                    ? "Bạn đã thanh toán cho đơn này, rạp sẽ hoàn tiền và gửi email thông báo khi hoàn tất."
                    : "Các ghế của đơn này đã được nhả, bạn có thể đặt lại nếu muốn.")}</p>
                """;

            return Build(recipientEmail, $"Đơn đặt vé {data.BookingCode} đã được huỷ", body);
        }

        public static EmailMessage BookingExpired(BookingEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Đơn đặt vé đã hết hạn</h2>
                <p>Đơn đặt vé <strong>{E(data.BookingCode)}</strong> đã hết thời gian giữ ghế{Reason(data.Reason) ?? ""}
                   nên các ghế đã được nhả cho khách khác.</p>
                {BookingDetails(data)}
                <p>Bạn có thể đặt lại vé trên ứng dụng nếu suất chiếu vẫn còn chỗ.</p>
                """;

            return Build(recipientEmail, $"Đơn đặt vé {data.BookingCode} đã hết hạn", body);
        }

        public static EmailMessage RefundRequested(PaymentEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Đã ghi nhận yêu cầu hoàn tiền</h2>
                <p>Rạp đã ghi nhận yêu cầu hoàn <strong>{data.RefundAmount ?? data.Amount:N0} VND</strong>
                   cho đơn đặt vé <strong>{E(data.BookingCode ?? data.BookingId.ToString())}</strong>
                   (mã hoàn tiền {E(data.RefundCode ?? "")}).</p>
                <p><strong>Lý do:</strong> {E(data.Reason ?? "")}</p>
                <p>Tiền sẽ được chuyển khoản lại vào tài khoản bạn đã dùng để thanh toán. Rạp sẽ gửi email khi hoàn tất.</p>
                """;

            return Build(recipientEmail, $"Yêu cầu hoàn tiền đơn {data.BookingCode}", body);
        }

        public static EmailMessage RefundCompleted(PaymentEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Đã hoàn tiền</h2>
                <p>Rạp đã hoàn <strong>{data.RefundAmount ?? data.Amount:N0} VND</strong>
                   cho đơn đặt vé <strong>{E(data.BookingCode ?? data.BookingId.ToString())}</strong>.</p>
                <p><strong>Mã giao dịch chuyển khoản:</strong> {E(data.RefundTransactionRef ?? "")}</p>
                <p>Nếu sau 3 ngày làm việc bạn chưa nhận được tiền, vui lòng liên hệ rạp kèm mã giao dịch trên.</p>
                """;

            return Build(recipientEmail, $"Đã hoàn tiền đơn {data.BookingCode}", body);
        }

        private static string BookingDetails(BookingEventData data)
        {
            var showTime = data.ShowTime?.ToString("dd/MM/yyyy HH:mm") ?? "Chưa cập nhật";

            return $"""
                <p><strong>Phim:</strong> {E(data.MovieTitle ?? "Mobile Cinema")}<br/>
                   <strong>Suất chiếu:</strong> {E(showTime)}<br/>
                   <strong>Ghế:</strong> {E(string.Join(", ", data.Seats))}<br/>
                   <strong>Tổng tiền:</strong> {data.TotalAmount:N0} VND</p>
                """;
        }

        private static string? Reason(string? reason)
        {
            return string.IsNullOrWhiteSpace(reason) ? null : $" ({E(reason)})";
        }

        private static string E(string value)
        {
            return Encoder.Encode(value);
        }

        private static EmailMessage Build(string recipientEmail, string subject, string body)
        {
            return new EmailMessage
            {
                RecipientEmail = recipientEmail,
                Subject = subject,
                Content = $"""
                    <html>
                      <body style="font-family:Arial,sans-serif;color:#202124;line-height:1.5">
                        {body}
                        <p>Cảm ơn bạn đã sử dụng Mobile Cinema.</p>
                      </body>
                    </html>
                    """
            };
        }
    }
}
