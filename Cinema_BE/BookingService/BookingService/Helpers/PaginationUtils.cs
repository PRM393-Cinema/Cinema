using BookingService.Exceptions;

namespace BookingService.Helpers
{
    public class PaginationUtils
    {
        public static (int PageNumber, int PageSize, string SortBy, string SortDir) Normalize(
            int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            pageNumber = pageNumber < 1 ? 1 : pageNumber;
            pageSize = pageSize <= 0 ? 10 : (pageSize > 50 ? 50 : pageSize);

            sortBy = string.IsNullOrWhiteSpace(sortBy) ? "createdAt" : sortBy.Trim();
            sortDir = string.IsNullOrWhiteSpace(sortDir) ? "desc" : sortDir.Trim().ToLowerInvariant();

            if (sortDir != "asc" && sortDir != "desc")
            {
                throw new BusinessException("Sort direction must be 'asc' or 'desc'.");
            }

            return (pageNumber, pageSize, sortBy, sortDir);
        }
    }
}
