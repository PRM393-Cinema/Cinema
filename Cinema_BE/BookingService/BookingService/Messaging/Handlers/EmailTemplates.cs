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
                <div style="background:#111e25;border:1px solid #23616b;border-radius:12px;padding:16px;margin:20px 0;color:#d1e5e8">
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
                <p>Yêu cầu đang chờ nhân viên xem xét. Với yêu cầu từ khách, vé và ghế vẫn còn hiệu lực trong lúc chờ.
                   Rạp sẽ gửi email khi hoàn tiền hoặc từ chối yêu cầu.</p>
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

        public static EmailMessage RefundRejected(PaymentEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Yêu cầu hoàn tiền bị từ chối</h2>
                <p>Yêu cầu hoàn tiền {E(data.RefundCode ?? "")} cho đơn
                   <strong>{E(data.BookingCode ?? data.BookingId.ToString())}</strong> đã bị từ chối.</p>
                <p><strong>Lý do:</strong> {E(data.Reason ?? "")}</p>
                <p>Tiền chưa được hoàn. Vui lòng liên hệ rạp nếu cần hỗ trợ.</p>
                """;
            return Build(recipientEmail, $"Yêu cầu hoàn tiền đơn {data.BookingCode} bị từ chối", body);
        }

        private static string BookingDetails(BookingEventData data)
        {
            var showTime = data.ShowTime?.ToString("dd/MM/yyyy HH:mm") ?? "Chưa cập nhật";

            return $"""
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0e141c;border:1px solid #2c3644;border-radius:12px;margin:20px 0">
                  <tr><td style="padding:14px 12px;color:#aeb8c6;vertical-align:top">Phim: </td><td style="padding:14px 12px;font-weight:bold;overflow-wrap:anywhere">{E(data.MovieTitle ?? "CosmoQ Cinema")}</td></tr>
                  <tr><td style="padding:10px 12px;color:#aeb8c6;vertical-align:top">Suất chiếu: </td><td style="padding:10px 12px">{E(showTime)}</td></tr>
                  <tr><td style="padding:10px 12px;color:#aeb8c6;vertical-align:top">Ghế: </td><td style="padding:10px 12px;overflow-wrap:anywhere">{E(string.Join(", ", data.Seats))}</td></tr>
                  <tr><td style="padding:14px 12px;color:#aeb8c6;vertical-align:top">Tổng tiền: </td><td style="padding:14px 12px;font-size:20px;font-weight:bold;color:#00d4e5">{data.TotalAmount:N0} VND</td></tr>
                </table>
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
                Content = $$"""
                    <!doctype html>
                    <html lang="vi">
                      <head>
                        <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
                        <style>h2 {font-size:24px;line-height:1.35;margin:0 0 20px;color:#f4f7fa} p {margin:0 0 16px}</style>
                      </head>
                      <body style="margin:0;background:#080c10;font-family:Arial,sans-serif;color:#e2e8f0;line-height:1.7">
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#080c10">
                          <tr><td align="center" style="padding:24px 12px">
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#141b25;border:1px solid #2c3644;border-radius:20px">
                              <tr><td style="padding:28px 24px">
                                <div data-email-chrome="true" style="color:#00d4e5;font-size:18px;font-weight:bold;letter-spacing:2px;margin-bottom:28px">COSMOQ <span style="color:#aeb8c6;font-size:12px;letter-spacing:1px">CINEMA</span></div>
                                {{body}}
                                <p>Cảm ơn bạn đã sử dụng CosmoQ Cinema.</p>
                                <div data-email-chrome="true" style="border-top:1px solid #2c3644;padding-top:20px;margin-top:24px;color:#aeb8c6;font-size:12px">CosmoQ Cinema · Email tự động, vui lòng không trả lời.</div>
                              </td></tr>
                            </table>
                          </td></tr>
                        </table>
                      </body>
                    </html>
                    """
            };
        }
    }
}
