namespace BookingService.DTOs.Responses
{
    public class BookingSeatResponse
    {
        public long Id { get; set; }

        public long SeatId { get; set; }

        public string SeatLabel { get; set; } = null!;

        public decimal Price { get; set; }
    }
}
