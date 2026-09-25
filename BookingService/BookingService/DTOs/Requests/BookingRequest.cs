using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class BookingRequest
    {
        [Required(ErrorMessage = "User id is required")]
        public long? UserId { get; set; }

        [Required(ErrorMessage = "Showtime id is required")]
        public long? ShowtimeId { get; set; }

        public string? MovieTitle { get; set; }

        public DateTime? ShowTime { get; set; }

        [Required(ErrorMessage = "At least one seat must be selected")]
        [MinLength(1, ErrorMessage = "At least one seat must be selected")]
        public List<SeatRequest> Seats { get; set; } = new();
    }
}
