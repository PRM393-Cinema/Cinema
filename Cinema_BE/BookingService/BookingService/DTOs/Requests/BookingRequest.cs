using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class BookingRequest
    {
        // Khách: server lấy từ token (không cần gửi). Staff/Admin tạo hộ khách thì bắt buộc gửi
        public long? UserId { get; set; }

        [Required(ErrorMessage = "Showtime id is required")]
        public long? ShowtimeId { get; set; }

        public string? MovieTitle { get; set; }

        // Email nhận vé. Khách tự đặt thì lấy email trong token; Staff đặt hộ thì điền email của khách
        [EmailAddress(ErrorMessage = "Customer email is invalid")]
        [MaxLength(150, ErrorMessage = "Customer email must not exceed 150 characters")]
        public string? CustomerEmail { get; set; }

        public DateTime? ShowTime { get; set; }

        [Required(ErrorMessage = "At least one seat must be selected")]
        [MinLength(1, ErrorMessage = "At least one seat must be selected")]
        public List<SeatRequest> Seats { get; set; } = new();
    }
}
