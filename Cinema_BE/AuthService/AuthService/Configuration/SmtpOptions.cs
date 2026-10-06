namespace AuthService.Configuration
{
    // Gmail: Host = smtp.gmail.com, Port = 587, EnableSsl = true, Password = App Password (xem docs/EMAIL_SETUP.md)
    public class SmtpOptions
    {
        public string Host { get; set; } = string.Empty;

        public int Port { get; set; } = 587;

        public bool EnableSsl { get; set; } = true;

        public string Username { get; set; } = string.Empty;

        public string Password { get; set; } = string.Empty;

        public string FromEmail { get; set; } = string.Empty;

        public string FromName { get; set; } = "Mobile Cinema";

        public int TimeoutSeconds { get; set; } = 10;

        public bool IsConfigured =>
            !string.IsNullOrWhiteSpace(Host) && !string.IsNullOrWhiteSpace(FromEmail);
    }
}
