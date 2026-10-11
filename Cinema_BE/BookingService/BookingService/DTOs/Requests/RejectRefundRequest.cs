using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests;

public class RejectRefundRequest
{
    [Required]
    [MaxLength(500)]
    public string? Reason { get; set; }
}
