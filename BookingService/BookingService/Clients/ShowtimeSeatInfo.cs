namespace BookingService.Clients;

public class ShowtimeSeatInfo
{
    public long SeatId { get; set; }

    public string SeatLabel { get; set; } = null!;

    public decimal Price { get; set; }
}