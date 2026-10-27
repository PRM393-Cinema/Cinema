using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Admin thêm / sửa món bắp nước
    public class ConcessionItemRequest
    {
        [Required(ErrorMessage = "Name is required")]
        [MaxLength(100, ErrorMessage = "Name must be at most 100 characters")]
        public string? Name { get; set; }

        [MaxLength(255, ErrorMessage = "Description must be at most 255 characters")]
        public string? Description { get; set; }

        [Required(ErrorMessage = "Price is required")]
        [Range(1000, 10_000_000, ErrorMessage = "Price must be between 1,000 and 10,000,000 VND")]
        public decimal? Price { get; set; }

        [MaxLength(500, ErrorMessage = "Image link must be at most 500 characters")]
        public string? ImageUrl { get; set; }

        // Bỏ trống: thêm mới thì đang bán, sửa thì giữ nguyên
        public bool? Active { get; set; }

        public int? SortOrder { get; set; }
    }
}
