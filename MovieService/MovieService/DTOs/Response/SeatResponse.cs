namespace ShowtimeService.DTOs.Response
{
    public class SeatResponse
    {
        public long Id { get; set; }
        public long RoomId { get; set; }
        public string SeatRow { get; set; } = null!;
        public int SeatNumber { get; set; }
        public string SeatType { get; set; } = null!;
    }
}
