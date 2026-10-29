namespace BookingService.DTOs.Responses
{
    public class ConcessionItemResponse
    {
        public long Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string? Description { get; set; }

        public decimal Price { get; set; }

        public string? ImageUrl { get; set; }

        public bool Active { get; set; }

        public int SortOrder { get; set; }
    }
}
