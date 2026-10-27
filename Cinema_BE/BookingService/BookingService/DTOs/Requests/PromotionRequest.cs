using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Admin thêm / sửa khuyến mãi
    public class PromotionRequest
    {
        // Bỏ trống: tự áp dụng khi đủ điều kiện; có mã: khách nhập (3–30 ký tự A-Z, 0-9, - _)
        [RegularExpression(@"^\s*[A-Za-z0-9_-]{3,30}\s*$", ErrorMessage = "Code must be 3 to 30 letters, digits, - or _")]
        public string? Code { get; set; }

        [Required(ErrorMessage = "Name is required")]
        [MaxLength(100, ErrorMessage = "Name must be at most 100 characters")]
        public string? Name { get; set; }

        [MaxLength(255, ErrorMessage = "Description must be at most 255 characters")]
        public string? Description { get; set; }

        // PERCENT (1–90) hoặc AMOUNT (số tiền)
        [Required(ErrorMessage = "Discount type is required")]
        [RegularExpression("^(PERCENT|AMOUNT|percent|amount)$", ErrorMessage = "Discount type must be PERCENT or AMOUNT")]
        public string? DiscountType { get; set; }

        [Required(ErrorMessage = "Discount value is required")]
        [Range(1, 10_000_000, ErrorMessage = "Discount value must be between 1 and 10,000,000")]
        public decimal? DiscountValue { get; set; }

        [Range(1000, 10_000_000, ErrorMessage = "Maximum discount must be between 1,000 and 10,000,000 VND")]
        public decimal? MaxDiscount { get; set; }

        [Range(1, 20, ErrorMessage = "Minimum tickets must be between 1 and 20")]
        public int? MinTickets { get; set; }

        // Thứ của ngày chiếu: 1 = thứ Hai ... 7 = Chủ nhật. Bỏ trống: mọi ngày
        public List<int>? DaysOfWeek { get; set; }

        public DateTime? StartsAt { get; set; }

        public DateTime? EndsAt { get; set; }

        [Range(1, 1_000_000, ErrorMessage = "Usage limit must be at least 1")]
        public int? UsageLimit { get; set; }

        public bool? Active { get; set; }
    }
}
