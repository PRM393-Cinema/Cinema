using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class SeatReservation
{
    public long Id { get; set; }

    public long ShowtimeId { get; set; }

    public long SeatId { get; set; }

    public string Status { get; set; } = null!; // HELD/ BOOKED/ EXPIRED/ AVAILABLE

    public DateTime? HeldUntil { get; set; }

    public long? BookingId { get; set; }
}
