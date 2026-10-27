namespace BookingService.Models;

// Đánh giá phim của khách đã xem (vé đã check-in). Mỗi khách một đánh giá cho một phim, sửa lại được.
public class MovieReview
{
    public long Id { get; set; }

    public long MovieId { get; set; }

    public long UserId { get; set; }

    public long BookingId { get; set; } // vé đã check-in chứng minh khách đã xem

    public string ReviewerName { get; set; } = null!;

    public short Rating { get; set; } // 1–5 sao

    public string? Comment { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }
}
