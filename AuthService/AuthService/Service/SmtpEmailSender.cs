using System.Net;
using System.Net.Mail;
using System.Net.Mime;
using System.Text;
using AuthService.Configuration;
using AuthService.DTOs;
using Microsoft.Extensions.Options;

namespace AuthService.Service
{
    // Gửi email qua SMTP (Gmail: smtp.gmail.com:587 + App Password, xem docs/EMAIL_SETUP.md).
    // Môi trường Development chưa cấu hình SMTP: không gửi mà in nội dung ra log để vẫn test được OTP.
    public class SmtpEmailSender : IEmailSender
    {
        private readonly SmtpOptions _options;
        private readonly IHostEnvironment _environment;
        private readonly ILogger<SmtpEmailSender> _logger;

        public SmtpEmailSender(
            IOptions<SmtpOptions> options,
            IHostEnvironment environment,
            ILogger<SmtpEmailSender> logger)
        {
            _options = options.Value;
            _environment = environment;
            _logger = logger;
        }

        public async Task SendAsync(EmailMessage email, CancellationToken cancellationToken = default)
        {
            if (!_options.IsConfigured)
            {
                if (!_environment.IsDevelopment())
                {
                    throw new InvalidOperationException("SMTP chưa được cấu hình (Smtp:Host, Smtp:FromEmail).");
                }

                _logger.LogWarning(
                    "SMTP chưa được cấu hình nên email KHÔNG được gửi, nội dung chỉ in ra log (Development).\nTo: {RecipientEmail}\nSubject: {Subject}\n{Content}",
                    email.RecipientEmail, email.Subject, email.TextContent);
                return;
            }

            using var message = new MailMessage
            {
                From = new MailAddress(_options.FromEmail, _options.FromName, Encoding.UTF8),
                Subject = email.Subject,
                SubjectEncoding = Encoding.UTF8,
                Body = email.TextContent,
                BodyEncoding = Encoding.UTF8,
                IsBodyHtml = false
            };

            message.To.Add(new MailAddress(email.RecipientEmail));

            // multipart/alternative: trình đọc mail ưu tiên bản HTML, không hiển thị được HTML thì dùng bản text
            message.AlternateViews.Add(
                AlternateView.CreateAlternateViewFromString(email.HtmlContent, Encoding.UTF8, MediaTypeNames.Text.Html));

            using var client = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.EnableSsl,
                DeliveryMethod = SmtpDeliveryMethod.Network,
                UseDefaultCredentials = false
            };

            if (!string.IsNullOrWhiteSpace(_options.Username))
            {
                client.Credentials = new NetworkCredential(_options.Username, _options.Password);
            }

            // SmtpClient.Timeout chỉ áp dụng cho Send đồng bộ, nên tự giới hạn thời gian cho bản async
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromSeconds(_options.TimeoutSeconds));

            await client.SendMailAsync(message, timeout.Token);
        }
    }
}
