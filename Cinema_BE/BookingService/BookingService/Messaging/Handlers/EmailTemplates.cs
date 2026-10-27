using System.Text.Encodings.Web;
using BookingService.DTOs;
using BookingService.Helpers;

namespace BookingService.Messaging.Handlers
{
    // Nội dung email gửi cho khách theo từng event (HTML, mọi dữ liệu đều được encode)
    public static class EmailTemplates
    {
        private static readonly HtmlEncoder Encoder = HtmlEncoder.Default;

        // Vé đã thanh toán: kèm mã QR (ảnh nhúng) để Staff quét check-in tại rạp
        public static EmailMessage BookingConfirmed(BookingEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Đặt vé thành công</h2>
                <p>Đơn đặt vé <strong>{E(data.BookingCode)}</strong> của bạn đã được xác nhận.</p>
                <div style="text-align:center;border:1px solid #e0e0e0;border-radius:8px;padding:16px;margin:16px 0">
                  <p style="margin:0 0 8px">Mã QR vào rạp</p>
                  <img src="cid:{TicketQr.EmailContentId}" alt="Mã QR vé {E(data.BookingCode)}" width="200" height="200"
                       style="display:block;margin:0 auto;width:200px;height:200px">
                  <p style="margin:8px 0 0;font-size:18px;font-weight:bold;letter-spacing:1px">{E(data.BookingCode)}</p>
                </div>
                {BookingDetails(data)}
                <div style="background:#fff3cd;border:1px solid #ffecb5;padding:12px;margin:16px 0;color:#664d03">
                  <strong>ĐẶC BIỆT LƯU Ý:</strong> Vui lòng có mặt trước giờ chiếu ít nhất 15 phút và xuất trình mã QR
                  (hoặc mã đặt vé) tại quầy để nhân viên check-in.
                </div>
                """;

            var email = Build(recipientEmail, $"Xác nhận đặt vé {data.BookingCode}", body);
            email.InlineImages.Add(new EmailImage
            {
                ContentId = TicketQr.EmailContentId,
                Content = TicketQr.Png(data.BookingCode)
            });
            return email;
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

        public static EmailMessage ShowtimeReminder(BookingEventData data, string recipientEmail)
        {
            var body = $"""
                <h2>Sắp tới giờ chiếu</h2>
                <p>Suất chiếu của vé <strong>{E(data.BookingCode)}</strong> sắp bắt đầu.
                   Bạn nhớ có mặt sớm 15 phút và đưa mã QR trên vé cho nhân viên soát vé.</p>
                {BookingDetails(data)}
                <p>Chúc bạn xem phim vui vẻ!</p>
                """;

            return Build(recipientEmail, $"Nhắc giờ chiếu: {data.MovieTitle ?? "vé"} {data.BookingCode}", body);
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
                <p><strong>Phim:</strong> {E(data.MovieTitle ?? "Mobile Cinema")}<br/>
                   <strong>Suất chiếu:</strong> {E(showTime)}<br/>
                   <strong>Ghế:</strong> {E(string.Join(", ", data.Seats))}<br/>{Snacks(data)}{Discount(data)}{Points(data)}
                   <strong>Tổng tiền:</strong> {data.TotalAmount:N0} VND</p>
                """;
        }

        private static string Snacks(BookingEventData data)
        {
            return data.Concessions.Count == 0
                ? string.Empty
                : $"\n   <strong>Bắp nước:</strong> {E(string.Join(", ", data.Concessions))}<br/>";
        }

        private static string Discount(BookingEventData data)
        {
            return data.DiscountAmount <= 0
                ? string.Empty
                : $"\n   <strong>Giảm giá:</strong> -{data.DiscountAmount:N0} VND ({E(data.PromotionName ?? "Khuyến mãi")})<br/>";
        }

        private static string Points(BookingEventData data)
        {
            var used = data.PointsUsed <= 0
                ? string.Empty
                : $"\n   <strong>Dùng điểm:</strong> {data.PointsUsed:N0} điểm (-{data.PointsDiscount:N0} VND)<br/>";
            var earned = data.PointsEarned <= 0
                ? string.Empty
                : $"\n   <strong>Điểm thưởng:</strong> +{data.PointsEarned:N0} điểm<br/>";
            return used + earned;
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
