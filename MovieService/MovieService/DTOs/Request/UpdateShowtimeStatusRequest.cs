using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    public class UpdateShowtimeStatusRequest
    {
        // OPEN = mở bán, CLOSED = ngừng bán (vé đã bán vẫn giữ). Huỷ suất chiếu dùng DELETE
        [Required(ErrorMessage = "Status is required.")]
        public string Status { get; set; } = null!;
    }
}
