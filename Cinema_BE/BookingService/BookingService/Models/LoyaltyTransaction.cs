namespace BookingService.Models;

// Một lần cộng / trừ điểm. EARN: cộng khi vé đã thanh toán; REDEEM: dùng điểm khi đặt vé;
// RETURN: trả lại điểm đã dùng khi vé không thành; REVERSE: thu hồi điểm đã cộng khi vé bị huỷ / hoàn tiền;
// ADJUST: Admin chỉnh tay.
public class LoyaltyTransaction
{
    public long Id { get; set; }

    public long UserId { get; set; }

    public long? BookingId { get; set; }

    public string Type { get; set; } = null!;

    public int Points { get; set; } // dương: cộng, âm: trừ

    public decimal SpendChange { get; set; } // phần thay đổi của tổng chi tiêu

    public string? Note { get; set; }

    public long? CreatedBy { get; set; } // Admin chỉnh tay

    public DateTime CreatedAt { get; set; }
}
