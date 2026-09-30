using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class Payment
{
    public long Id { get; set; }

    public string PaymentCode { get; set; } = null!;

    public long BookingId { get; set; }

    public long UserId { get; set; }

    public decimal Amount { get; set; }

    public string? Method { get; set; }

    public string Status { get; set; } = null!; // PENDING/ SUCCESS/ FAILED

    public string? TransactionRef { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }
}
