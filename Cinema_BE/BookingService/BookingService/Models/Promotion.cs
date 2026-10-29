namespace BookingService.Models;

// Khuyến mãi giảm tiền vé. Không có mã: tự áp dụng khi đủ điều kiện (vd giảm giá thứ Ba);
// có mã: khách nhập mã voucher.
public class Promotion
{
    public long Id { get; set; }

    public string? Code { get; set; }

    public string Name { get; set; } = null!;

    public string? Description { get; set; }

    public string DiscountType { get; set; } = "PERCENT"; // PERCENT / AMOUNT

    public decimal DiscountValue { get; set; }

    public decimal? MaxDiscount { get; set; } // trần số tiền giảm của PERCENT

    public int MinTickets { get; set; } = 1;

    // Thứ của ngày chiếu, 1 = thứ Hai ... 7 = Chủ nhật, cách nhau dấu phẩy. null: mọi ngày
    public string? DaysOfWeek { get; set; }

    public DateTime? StartsAt { get; set; }

    public DateTime? EndsAt { get; set; }

    public int? UsageLimit { get; set; } // số lượt dùng tối đa (đếm khi vé đã thanh toán)

    public int UsedCount { get; set; }

    public bool Active { get; set; } = true;

    public DateTime CreatedAt { get; set; }
}
