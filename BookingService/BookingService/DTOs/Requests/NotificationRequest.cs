using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class NotificationRequest
    {
        [Required(ErrorMessage = "User id is required")]
        public long? UserId { get; set; }

        public long? BookingId { get; set; }

        [Required(ErrorMessage = "Recipient email is required")]
        [EmailAddress(ErrorMessage = "Recipient email is invalid")]
        public string? RecipientEmail { get; set; }

        [Required(ErrorMessage = "Subject is required")]
        public string? Subject { get; set; }

        [Required(ErrorMessage = "Type is required")]
        public string? Type { get; set; }

        [Required(ErrorMessage = "Content is required")]
        public string? Content { get; set; }
    }
}
