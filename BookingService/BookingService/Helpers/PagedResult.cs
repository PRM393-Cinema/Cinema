namespace BookingService.Helpers
{
    // là response model dùng để trả ra ngoài API.
    public class PagedResult<T>
    {
        public PagedResult()
        {
        }

        public PagedResult(
            IEnumerable<T> items,
            int pageNumber,
            int pageSize,
            int totalPages,
            int totalCount)
        {
            Items = items.ToList();
            PageNumber = pageNumber;
            PageSize = pageSize;
            TotalPages = totalPages;
            TotalCount = totalCount;
        }

        public List<T> Items { get; set; } = new();
        public int PageNumber { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
        public int TotalCount { get; set; }
        public bool HasPrevious => PageNumber > 1;
        public bool HasNext => PageNumber < TotalPages;
    }
}
