namespace ShowtimeService.DTOs.Response
{
    public class ShowtimeResponse
    {
        public long Id { get; set; }
        public long MovieId { get; set; }
        public long RoomId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public decimal Price { get; set; }
        public string Status { get; set; } = null!;
    }
}
