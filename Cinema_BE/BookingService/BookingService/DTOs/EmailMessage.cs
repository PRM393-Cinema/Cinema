namespace BookingService.DTOs
{
    public class EmailMessage
    {
        public string RecipientEmail { get; set; } = null!;

        public string Subject { get; set; } = null!;

        public string Content { get; set; } = null!;

        // Ảnh nhúng trong nội dung HTML (<img src="cid:ContentId">), vd mã QR trên vé
        public List<EmailImage> InlineImages { get; set; } = new();
    }

    public class EmailImage
    {
        public string ContentId { get; set; } = null!;

        public string MediaType { get; set; } = "image/png";

        public byte[] Content { get; set; } = [];
    }
}
