using System.Net.Http.Json;
using AuthService.Configuration;
using AuthService.DTOs;
using Microsoft.Extensions.Options;

namespace AuthService.Service
{
    // Gửi email qua HTTPS API của Brevo (POST /v3/smtp/email), dùng khi cấu hình Brevo:ApiKey.
    // Render gói free chặn cổng SMTP nên bản deploy gửi email bằng cách này (xem docs/EMAIL_SETUP.md).
    public class BrevoEmailSender : IEmailSender
    {
        private readonly HttpClient _httpClient;
        private readonly BrevoOptions _options;

        public BrevoEmailSender(HttpClient httpClient, IOptions<BrevoOptions> options)
        {
            _httpClient = httpClient;
            _options = options.Value;
        }

        public async Task SendAsync(EmailMessage email, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(_options.FromEmail))
            {
                throw new InvalidOperationException("Brevo chưa được cấu hình người gửi (Brevo:FromEmail).");
            }

            using var request = new HttpRequestMessage(HttpMethod.Post, "v3/smtp/email")
            {
                Content = JsonContent.Create(new
                {
                    sender = new { name = _options.FromName, email = _options.FromEmail },
                    to = new[] { new { email = email.RecipientEmail } },
                    subject = email.Subject,
                    htmlContent = email.HtmlContent,
                    textContent = email.TextContent
                })
            };
            request.Headers.Add("api-key", _options.ApiKey);

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                // Brevo trả lý do trong body, vd {"code":"unauthorized","message":"Key not found"}
                var reason = await response.Content.ReadAsStringAsync(cancellationToken);
                throw new HttpRequestException(
                    $"Brevo từ chối gửi email ({(int)response.StatusCode}): {reason}",
                    null,
                    response.StatusCode);
            }
        }
    }
}
