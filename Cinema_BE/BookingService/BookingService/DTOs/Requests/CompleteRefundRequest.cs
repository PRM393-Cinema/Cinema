using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Staff đã chuyển khoản trả khách: ghi lại mã giao dịch chuyển khoản
    public class CompleteRefundRequest
    {
        [Required(ErrorMessage = "Transaction reference is required")]
        [MaxLength(100, ErrorMessage = "Transaction reference must not exceed 100 characters")]
        public string? TransactionRef { get; set; }

        [MaxLength(500, ErrorMessage = "Note must not exceed 500 characters")]
        public string? Note { get; set; }
    }
}
