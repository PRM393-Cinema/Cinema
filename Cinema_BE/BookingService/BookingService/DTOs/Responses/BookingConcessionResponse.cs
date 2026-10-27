namespace BookingService.DTOs.Responses
{
    public class BookingConcessionResponse
    {
        public long ItemId { get; set; }

        public string Name { get; set; } = string.Empty;

        public decimal UnitPrice { get; set; }

        public int Quantity { get; set; }

        public decimal Amount { get; set; }
    }
}
