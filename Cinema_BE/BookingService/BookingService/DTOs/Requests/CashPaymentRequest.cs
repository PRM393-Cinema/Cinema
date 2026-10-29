using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Staff thu tiền mặt tại quầy cho một booking đang giữ ghế
    public class CashPaymentRequest
    {
        [Required(ErrorMessage = "Booking id is required")]
        public long? BookingId { get; set; }

        // Số tiền khách đưa, ít nhất bằng tổng tiền vé (tiền thừa trả lại khách)
        [Required(ErrorMessage = "Amount received is required")]
        public decimal? AmountReceived { get; set; }

        // Email nhận vé (kèm QR); không có thì dùng email trên booking, không có nữa thì không gửi
        [EmailAddress(ErrorMessage = "Recipient email is invalid")]
        [MaxLength(150, ErrorMessage = "Recipient email must not exceed 150 characters")]
        public string? RecipientEmail { get; set; }
    }
}
