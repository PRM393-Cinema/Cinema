using Microsoft.OpenApi.MicrosoftExtensions;
using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    public class ShowtimeRequest
    {
        [Required(ErrorMessage = "MovieId is required.")]
        public long MovieId { get; set; }

        [Required(ErrorMessage = "RoomId is required.")]
        public long RoomId { get; set; }

        [Required(ErrorMessage = "StartTime is required.")]
        public DateTime StartTime { get; set; }

        [Required(ErrorMessage = "EndTime is required.")]
        public DateTime EndTime { get; set; }

        [Required(ErrorMessage = "Price is required.")]
        [Range(0, double.MaxValue, ErrorMessage = "Price must be a non-negative value.")]
        public decimal Price { get; set; }
        // OPEN (mặc định) / CLOSED. Không gửi khi sửa thì giữ nguyên trạng thái hiện tại
        public string? Status { get; set; }
    }
}
