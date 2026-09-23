using System;
using System.Collections.Generic;

namespace ShowtimeService.Models;

public partial class Seat
{
    public long Id { get; set; }

    public long RoomId { get; set; }

    public string SeatRow { get; set; } = null!;

    public int SeatNumber { get; set; }

    public string SeatType { get; set; } = null!;

    public virtual Room Room { get; set; } = null!;
}
