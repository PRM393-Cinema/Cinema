using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Admin cộng (số dương) hoặc trừ (số âm) điểm của khách, kèm lý do
    public class LoyaltyAdjustRequest
    {
        [Required(ErrorMessage = "Points are required")]
        [Range(-1_000_000, 1_000_000, ErrorMessage = "Points must be between -1,000,000 and 1,000,000")]
        public int? Points { get; set; }

        [Required(ErrorMessage = "A reason is required")]
        [MaxLength(255, ErrorMessage = "The reason must be at most 255 characters")]
        public string? Note { get; set; }
    }
}
