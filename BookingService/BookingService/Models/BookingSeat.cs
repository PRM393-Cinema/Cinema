using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class BookingSeat
{
    public long Id { get; set; }

    public long BookingId { get; set; }

    public long SeatId { get; set; }

    public string SeatLabel { get; set; } = null!;

    public decimal Price { get; set; }

    public virtual Booking Booking { get; set; } = null!;
}
