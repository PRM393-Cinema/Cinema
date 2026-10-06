using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class Notification
{
    public long Id { get; set; }

    public long UserId { get; set; }

    public long? BookingId { get; set; }

    public string Type { get; set; } = null!;

    public string? Content { get; set; }

    public string Status { get; set; } = null!; // PENDING/ SENT/ CANCELLED

    public DateTime CreatedAt { get; set; }

    public string? ErrorMessage { get; set; }

    public string? EventId { get; set; }

    public string? RecipientEmail { get; set; }

    public DateTime? SentAt { get; set; }

    public string? Subject { get; set; }
}
