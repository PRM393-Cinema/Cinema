namespace BookingService.Clients.Interfaces
{
    public interface IShowtimeClient
    {
            Task<List<ShowtimeSeatInfo>> GetSeatsAsync(
                long showtimeId,
                List<long> seatIds);
    }
}
