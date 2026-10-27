namespace BookingService.Models;

// Điểm thành viên của một khách hàng (user_id bên AuthService). 1 điểm = 1.000đ khi dùng.
public class LoyaltyAccount
{
    public long UserId { get; set; }

    public int Points { get; set; }

    // Tổng tiền vé đã thanh toán (trừ vé đã hoàn), quyết định hạng thành viên
    public decimal LifetimeSpend { get; set; }

    public string Tier { get; set; } = "MEMBER"; // MEMBER / VIP / VVIP

    public DateTime CreatedAt { get; set; }

    public DateTime UpdatedAt { get; set; }
}
