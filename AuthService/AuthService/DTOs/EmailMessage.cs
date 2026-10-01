namespace AuthService.DTOs
{
    public class EmailMessage
    {
        public string RecipientEmail { get; set; } = null!;

        public string Subject { get; set; } = null!;

        public string HtmlContent { get; set; } = null!;

        // Bản text thuần: dùng cho trình đọc mail không hiển thị HTML và để in ra log khi chưa cấu hình SMTP
        public string TextContent { get; set; } = null!;
    }
}
