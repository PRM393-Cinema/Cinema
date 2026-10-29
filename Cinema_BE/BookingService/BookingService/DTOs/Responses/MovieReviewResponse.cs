using BookingService.Helpers;

namespace BookingService.DTOs.Responses
{
    public class MovieReviewResponse
    {
        public long Id { get; set; }

        public long MovieId { get; set; }

        public string? MovieTitle { get; set; }

        public long BookingId { get; set; }

        public string ReviewerName { get; set; } = string.Empty;

        public int Rating { get; set; }

        public string? Comment { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime UpdatedAt { get; set; }

        // Đánh giá của người đang xem (được sửa / xoá)
        public bool Mine { get; set; }
    }

    // Đánh giá phim của một vé: vé đã check-in thì được viết; Review là đánh giá hiện có của khách cho phim đó
    public class BookingReviewResponse
    {
        public long BookingId { get; set; }

        public long MovieId { get; set; }

        public bool CanReview { get; set; }

        public MovieReviewResponse? Review { get; set; }
    }

    // Điểm trung bình, số đánh giá theo từng mức sao và một trang đánh giá mới nhất
    public class MovieReviewsResponse
    {
        public long MovieId { get; set; }

        public double Average { get; set; }

        public int Count { get; set; }

        // Số đánh giá 1..5 sao (chỉ số 0 là 1 sao)
        public int[] Stars { get; set; } = new int[5];

        public PagedResult<MovieReviewResponse> Reviews { get; set; } = new();
    }
}
