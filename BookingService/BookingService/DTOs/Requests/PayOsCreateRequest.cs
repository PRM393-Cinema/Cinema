using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class PayOsCreateRequest
    {
        [Required(ErrorMessage = "Booking id is required")]
        public long? BookingId { get; set; }

        [Required(ErrorMessage = "User id is required")]
        public long? UserId { get; set; }

        [Required(ErrorMessage = "Amount is required")]
        [Range(
            0.01,
            double.MaxValue,
            ErrorMessage = "Amount must be greater than 0"
        )]
        public decimal? Amount { get; set; }

        /// <summary>
        /// Short label shown on the PayOS checkout page.
        /// PayOS caps it at 25 characters.
        /// </summary>
        [MaxLength(25, ErrorMessage = "Description must not exceed 25 characters")]
        public string? Description { get; set; }

        [Required(ErrorMessage = "Return URL is required")]
        [Url(ErrorMessage = "Return URL is invalid")]
        public string? ReturnUrl { get; set; }

        [Required(ErrorMessage = "Cancel URL is required")]
        [Url(ErrorMessage = "Cancel URL is invalid")]
        public string? CancelUrl { get; set; }
    }
}
