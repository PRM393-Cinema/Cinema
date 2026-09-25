using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class PaymentRequest
    {
        [Required(ErrorMessage = "Booking id is required")]
        public long? BookingId { get; set; }

        [Required(ErrorMessage = "User id is required")]
        public long? UserId { get; set; }

        [Required(ErrorMessage = "Recipient email is required")]
        [EmailAddress(ErrorMessage = "Recipient email is invalid")]
        public string? RecipientEmail { get; set; }

        [Required(ErrorMessage = "Amount is required")]
        [Range(
            0.01,
            double.MaxValue,
            ErrorMessage = "Amount must be greater than 0"
        )]
        public decimal? Amount { get; set; }

        [Required(ErrorMessage = "Payment method is required")]
        public string? Method { get; set; }
    }
}
