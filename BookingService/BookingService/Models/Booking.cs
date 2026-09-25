using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class Booking
{
    public long Id { get; set; }

    public string BookingCode { get; set; } = null!;

    public long UserId { get; set; }

    public long ShowtimeId { get; set; }

    public string Status { get; set; } = null!; //PENDING / CONFIRMED / CANCELLED / EXPIRED

    public decimal TotalAmount { get; set; }

    public long? PaymentId { get; set; }

    public string? MovieTitle { get; set; }

    public DateTime? ShowTime { get; set; }

    public DateTime? ExpiresAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual ICollection<BookingSeat> BookingSeats { get; set; } = new List<BookingSeat>();
}
