using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Xem trước số tiền được giảm trước khi giữ ghế; lúc đặt vé server tính lại
    public class PromotionQuoteRequest
    {
        [Required(ErrorMessage = "Showtime id is required")]
        public long? ShowtimeId { get; set; }

        [Range(0, 1_000_000_000, ErrorMessage = "Ticket amount is invalid")]
        public decimal TicketAmount { get; set; }

        [Range(1, 50, ErrorMessage = "Tickets must be between 1 and 50")]
        public int Tickets { get; set; } = 1;

        [MaxLength(30, ErrorMessage = "Promo code must be at most 30 characters")]
        public string? Code { get; set; }
    }
}
