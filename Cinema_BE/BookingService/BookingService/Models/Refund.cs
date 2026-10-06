namespace BookingService.Models;

// Yêu cầu hoàn tiền của một payment (bảng refunds trong cinema_payment_db)
public partial class Refund
{
    public long Id { get; set; }

    public string RefundCode { get; set; } = null!;

    public long PaymentId { get; set; }

    public long BookingId { get; set; }

    public long UserId { get; set; }

    public decimal Amount { get; set; }

    public string Reason { get; set; } = null!;

    public string Status { get; set; } = null!; // PENDING / COMPLETED

    public string? TransactionRef { get; set; }

    public string? Note { get; set; }

    public long? ProcessedBy { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? ProcessedAt { get; set; }
}
