using System.Net.Http.Json;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using BookingService.Clients.Interfaces;
using BookingService.Configuration;
using BookingService.DTOs;
using BookingService.Exceptions;
using Microsoft.Extensions.Options;

namespace BookingService.Clients.Implementations
{
    // Gửi email qua HTTPS API của Brevo (POST /v3/smtp/email), dùng khi cấu hình Brevo:ApiKey.
    // Render gói free chặn cổng SMTP nên bản deploy gửi email bằng cách này (xem docs/EMAIL_SETUP.md).
    public sealed class BrevoEmailSender : IEmailSender
    {
        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        private readonly HttpClient _httpClient;
        private readonly BrevoOptions _options;

        public BrevoEmailSender(HttpClient httpClient, IOptions<BrevoOptions> options)
        {
            _httpClient = httpClient;
            _options = options.Value;
        }

        public async Task SendAsync(
            EmailMessage email,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(_options.FromEmail))
            {
                throw new ExternalServiceException(
                    "Brevo email settings are not configured.");
            }

            // Brevo không hỗ trợ ảnh nhúng theo Content-ID: ảnh (vd mã QR vé) gửi thành file đính kèm,
            // còn thẻ <img src="cid:..."> trong nội dung được thay bằng lời nhắc mở file đó
            var html = email.Content;
            foreach (var image in email.InlineImages)
            {
                var note =
                    $"""<p style="margin:0">Ảnh nằm trong file đính kèm <strong>{HtmlEncoder.Default.Encode(image.FileName)}</strong></p>""";
                html = Regex.Replace(
                    html,
                    $"""<img\b[^>]*\bsrc="cid:{Regex.Escape(image.ContentId)}"[^>]*>""",
                    _ => note,
                    RegexOptions.IgnoreCase);
            }

            using var request = new HttpRequestMessage(HttpMethod.Post, "v3/smtp/email")
            {
                Content = JsonContent.Create(
                    new
                    {
                        sender = new { name = _options.FromName, email = _options.FromEmail },
                        to = new[] { new { email = email.RecipientEmail } },
                        subject = email.Subject,
                        htmlContent = html,
                        attachment = email.InlineImages.Count == 0
                            ? null
                            : email.InlineImages
                                .Select(image => new
                                {
                                    name = image.FileName,
                                    content = Convert.ToBase64String(image.Content)
                                })
                                .ToArray()
                    },
                    options: JsonOptions)
            };
            request.Headers.Add("api-key", _options.ApiKey);

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                // Brevo trả lý do trong body, vd {"code":"unauthorized","message":"Key not found"}
                var reason = await response.Content.ReadAsStringAsync(cancellationToken);
                throw new ExternalServiceException(
                    $"Brevo rejected the email ({(int)response.StatusCode}): {reason}");
            }
        }
    }
}
