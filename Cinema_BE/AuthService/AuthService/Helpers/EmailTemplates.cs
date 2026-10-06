using System.Text.Encodings.Web;
using System.Text.Unicode;
using AuthService.DTOs;

namespace AuthService.Helpers
{
    // Nội dung các email AuthService gửi cho người dùng (bản HTML + bản text thuần)
    public static class EmailTemplates
    {
        private const string AppName = "Mobile Cinema";

        // Vẫn escape ký tự HTML (<, >, &, ") nhưng giữ nguyên chữ tiếng Việt
        private static readonly HtmlEncoder Encoder = HtmlEncoder.Create(UnicodeRanges.All);

        public static EmailMessage VerifyEmailOtp(string recipientEmail, string? fullName, string otp, int expiryMinutes)
        {
            return OtpEmail(
                recipientEmail,
                fullName,
                otp,
                expiryMinutes,
                subject: $"Mã xác thực email {AppName}",
                intro: "Cảm ơn bạn đã đăng ký tài khoản. Nhập mã dưới đây trong ứng dụng để xác thực email:",
                ignoreNote: "Nếu bạn không đăng ký tài khoản, hãy bỏ qua email này.");
        }

        public static EmailMessage ResetPasswordOtp(string recipientEmail, string? fullName, string otp, int expiryMinutes)
        {
            return OtpEmail(
                recipientEmail,
                fullName,
                otp,
                expiryMinutes,
                subject: $"Mã đặt lại mật khẩu {AppName}",
                intro: "Bạn vừa yêu cầu đặt lại mật khẩu. Nhập mã dưới đây trong ứng dụng để đặt mật khẩu mới:",
                ignoreNote: "Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này. Mật khẩu hiện tại vẫn giữ nguyên.");
        }

        public static EmailMessage Welcome(string recipientEmail, string? fullName)
        {
            var name = DisplayName(fullName);

            var html = $"""
                <html>
                  <body style="font-family:Arial,sans-serif;color:#202124;line-height:1.5">
                    <h2>Chào mừng bạn đến với {AppName}!</h2>
                    <p>Xin chào {Encode(name)},</p>
                    <p>Tài khoản <strong>{Encode(recipientEmail)}</strong> đã được xác thực thành công.</p>
                    <p>Giờ bạn có thể xem lịch chiếu, chọn ghế, đặt vé và thanh toán ngay trên ứng dụng.
                       Thông tin vé sẽ được gửi về email này sau mỗi lần đặt vé thành công.</p>
                    <p>Chúc bạn có những giờ phút xem phim thật vui!</p>
                  </body>
                </html>
                """;

            var text = $"""
                Xin chào {name},

                Tài khoản {recipientEmail} đã được xác thực thành công.
                Giờ bạn có thể xem lịch chiếu, chọn ghế, đặt vé và thanh toán ngay trên ứng dụng.
                Thông tin vé sẽ được gửi về email này sau mỗi lần đặt vé thành công.

                Chúc bạn có những giờ phút xem phim thật vui!
                """;

            return new EmailMessage
            {
                RecipientEmail = recipientEmail,
                Subject = $"Chào mừng bạn đến với {AppName}",
                HtmlContent = html,
                TextContent = text
            };
        }

        private static EmailMessage OtpEmail(
            string recipientEmail,
            string? fullName,
            string otp,
            int expiryMinutes,
            string subject,
            string intro,
            string ignoreNote)
        {
            var name = DisplayName(fullName);
            var warning = $"Mã có hiệu lực trong {expiryMinutes} phút và chỉ dùng được một lần. " +
                          $"Không chia sẻ mã này với bất kỳ ai, kể cả nhân viên {AppName}.";

            var html = $"""
                <html>
                  <body style="font-family:Arial,sans-serif;color:#202124;line-height:1.5">
                    <h2>{AppName}</h2>
                    <p>Xin chào {Encode(name)},</p>
                    <p>{intro}</p>
                    <p style="font-size:32px;font-weight:bold;letter-spacing:8px;margin:24px 0">{otp}</p>
                    <p>{warning}</p>
                    <p style="color:#5f6368">{ignoreNote}</p>
                  </body>
                </html>
                """;

            var text = $"""
                Xin chào {name},

                {intro}

                {otp}

                {warning}
                {ignoreNote}
                """;

            return new EmailMessage
            {
                RecipientEmail = recipientEmail,
                Subject = subject,
                HtmlContent = html,
                TextContent = text
            };
        }

        private static string DisplayName(string? fullName) =>
            string.IsNullOrWhiteSpace(fullName) ? "bạn" : fullName.Trim();

        private static string Encode(string value) => Encoder.Encode(value);
    }
}
