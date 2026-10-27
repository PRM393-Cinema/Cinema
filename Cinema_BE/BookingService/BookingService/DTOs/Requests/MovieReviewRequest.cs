using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Khách đánh giá phim của một vé đã check-in. Đã đánh giá phim này thì cập nhật đánh giá cũ
    public class MovieReviewRequest
    {
        [Required(ErrorMessage = "Booking id is required")]
        public long? BookingId { get; set; }

        [Required(ErrorMessage = "Rating is required")]
        [Range(1, 5, ErrorMessage = "Rating must be from 1 to 5 stars")]
        public int? Rating { get; set; }

        [MaxLength(1000, ErrorMessage = "Comment must be at most 1000 characters")]
        public string? Comment { get; set; }
    }
}
