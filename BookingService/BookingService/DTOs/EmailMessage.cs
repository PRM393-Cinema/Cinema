namespace BookingService.DTOs
{
    public class EmailMessage
    {
        public string RecipientEmail { get; set; } = null!;

        public string Subject { get; set; } = null!;

        public string Content { get; set; } = null!;
    }
}
