namespace ShowtimeService.DTOs.Response
{
    public class RoomResponse
    {
        public long Id { get; set; }
        public string Name { get; set; } = null!;
        public int TotalSeats { get; set; }
    }
}
