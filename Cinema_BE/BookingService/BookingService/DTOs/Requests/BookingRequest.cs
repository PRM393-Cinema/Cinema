using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class BookingRequest
    {
        // Khách: server lấy từ token (không cần gửi). Staff/Admin đặt hộ khách có tài khoản thì gửi id của khách;
        // bỏ trống là vé khách vãng lai bán tại quầy
        public long? UserId { get; set; }

        [Required(ErrorMessage = "Showtime id is required")]
        public long? ShowtimeId { get; set; }

        public string? MovieTitle { get; set; }

        // Email nhận vé. Khách tự đặt thì lấy email trong token; Staff đặt hộ thì điền email của khách
        [EmailAddress(ErrorMessage = "Customer email is invalid")]
        [MaxLength(150, ErrorMessage = "Customer email must not exceed 150 characters")]
        public string? CustomerEmail { get; set; }

        // Số điện thoại khách vãng lai (không bắt buộc)
        [MaxLength(20, ErrorMessage = "Customer phone must not exceed 20 characters")]
        public string? CustomerPhone { get; set; }

        public DateTime? ShowTime { get; set; }

        [Required(ErrorMessage = "At least one seat must be selected")]
        [MinLength(1, ErrorMessage = "At least one seat must be selected")]
        public List<SeatRequest> Seats { get; set; } = new();

        // Mã voucher (không bắt buộc). Không có mã thì tự áp khuyến mãi tốt nhất đang có
        [MaxLength(30, ErrorMessage = "Promo code must be at most 30 characters")]
        public string? PromotionCode { get; set; }

        // Bắp nước mua kèm (không bắt buộc)
        public List<BookingConcessionRequest> Concessions { get; set; } = new();
    }
}
