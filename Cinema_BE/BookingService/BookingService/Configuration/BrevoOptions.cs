namespace BookingService.Configuration
{
    // Gửi email qua HTTPS API của Brevo thay cho SMTP, dùng khi máy chủ chặn cổng SMTP (vd Render gói free).
    // Có ApiKey thì Brevo được dùng thay SMTP (xem docs/EMAIL_SETUP.md)
    public class BrevoOptions
    {
        public string BaseUrl { get; set; } = "https://api.brevo.com/";

        public string ApiKey { get; set; } = string.Empty;

        // Địa chỉ người gửi phải được xác minh trên Brevo (Senders)
        public string FromEmail { get; set; } = string.Empty;

        public string FromName { get; set; } = "Mobile Cinema";

        public int TimeoutSeconds { get; set; } = 10;

        public bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey);
    }
}
