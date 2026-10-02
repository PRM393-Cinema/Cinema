namespace BookingService.Clients;

// GET api/showtimes/{id} của MovieService
public class ShowtimeInfo
{
    public long Id { get; set; }

    public long MovieId { get; set; }

    public DateTime StartTime { get; set; }

    public DateTime EndTime { get; set; }

    public string Status { get; set; } = null!;
}
