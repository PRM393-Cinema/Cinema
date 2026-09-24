using System;
using System.Collections.Generic;

namespace ShowtimeService.Models;

public partial class Room
{
    public long Id { get; set; }

    public string Name { get; set; } = null!;

    public int TotalSeats { get; set; }

    public virtual ICollection<Seat> Seats { get; set; } = new List<Seat>();

    public virtual ICollection<Showtime> Showtimes { get; set; } = new List<Showtime>();
}
