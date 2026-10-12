using System.Text.Encodings.Web;
using System.Text.Unicode;
using AuthService.DTOs;

namespace AuthService.Helpers
{
    // Nội dung các email AuthService gửi cho người dùng (bản HTML + bản text thuần)
    public static class EmailTemplates
    {
        private const string AppName = "CosmoQ Cinema";

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

            var html = Layout($"""
                    <h2>Chào mừng bạn đến với {AppName}!</h2>
                    <p>Xin chào {Encode(name)},</p>
                    <p>Tài khoản <strong>{Encode(recipientEmail)}</strong> đã được xác thực thành công.</p>
                    <p>Giờ bạn có thể xem lịch chiếu, chọn ghế, đặt vé và thanh toán ngay trên ứng dụng.
                       Thông tin vé sẽ được gửi về email này sau mỗi lần đặt vé thành công.</p>
                    <p>Chúc bạn có những giờ phút xem phim thật vui!</p>
                """);

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

            var html = Layout($"""
                    <h2>{Encode(subject)}</h2>
                    <p>Xin chào {Encode(name)},</p>
                    <p>{Encode(intro)}</p>
                    <div style="background:#111e25;border:1px solid #23616b;border-radius:16px;padding:24px 12px;margin:24px 0;text-align:center">
                      <span style="font-family:Consolas,monospace;font-size:32px;font-weight:bold;letter-spacing:6px;color:#00d4e5">{Encode(otp)}</span>
                    </div>
                    <p>{Encode(warning)}</p>
                    <p style="color:#aeb8c6;font-size:13px">{Encode(ignoreNote)}</p>
                """);

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

        private static string Layout(string body) => $$"""
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
                        <div data-email-chrome="true" style="border-top:1px solid #2c3644;padding-top:20px;margin-top:24px;color:#aeb8c6;font-size:12px">CosmoQ Cinema · Email tự động, vui lòng không trả lời.</div>
                      </td></tr>
                    </table>
                  </td></tr>
                </table>
              </body>
            </html>
            """;
    }
}
