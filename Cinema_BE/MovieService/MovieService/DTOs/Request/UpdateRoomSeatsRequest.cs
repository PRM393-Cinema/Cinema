using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    // Đổi tổng số ghế của phòng; ghế được thêm / bỏ ở cuối sơ đồ
    public class UpdateRoomSeatsRequest
    {
        [Required(ErrorMessage = "TotalSeats is required.")]
        [Range(1, 2600, ErrorMessage = "Total seats must be between 1 and 2600.")]
        public int TotalSeats { get; set; }

        // Số ghế mỗi hàng khi thêm ghế; bỏ trống thì dùng hàng dài nhất hiện có
        [Range(1, 100, ErrorMessage = "Seats per row must be between 1 and 100.")]
        public int? SeatsPerRow { get; set; }

        // Loại của ghế mới, mặc định NORMAL
        public string? SeatType { get; set; }
    }
}
