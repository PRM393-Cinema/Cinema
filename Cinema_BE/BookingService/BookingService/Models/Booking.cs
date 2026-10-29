using System;
using System.Collections.Generic;

namespace BookingService.Models;

public partial class Booking
{
    public long Id { get; set; }

    public string BookingCode { get; set; } = null!;

    public long? UserId { get; set; } // null: khách vãng lai mua tại quầy, không có tài khoản

    public string? CustomerEmail { get; set; } // email nhận vé / thông báo

    public string? CustomerPhone { get; set; } // số điện thoại khách vãng lai (nếu khách cho)

    public long ShowtimeId { get; set; }

    public string Status { get; set; } = null!; // PENDING / CONFIRMED / REFUND_PENDING / CANCELLED / EXPIRED

    public decimal TotalAmount { get; set; } // số tiền phải trả: tiền vé + bắp nước

    public decimal ConcessionsAmount { get; set; } // tiền bắp nước trong tổng tiền

    public decimal DiscountAmount { get; set; } // tiền vé được giảm nhờ khuyến mãi (đã trừ trong tổng tiền)

    public long? PromotionId { get; set; }

    public string? PromotionCode { get; set; } // mã voucher khách nhập; null nếu khuyến mãi tự áp dụng

    public string? PromotionName { get; set; }

    public int PointsUsed { get; set; } // điểm thành viên khách dùng cho đơn này

    public decimal PointsDiscount { get; set; } // số tiền giảm nhờ điểm (đã trừ trong tổng tiền)

    public int PointsEarned { get; set; } // điểm được cộng khi vé đã thanh toán

    public DateTime? RemindedAt { get; set; } // đã gửi nhắc giờ chiếu

    public long? PaymentId { get; set; }

    public string? MovieTitle { get; set; }

    public DateTime? ShowTime { get; set; }

    public DateTime? ExpiresAt { get; set; }

    public DateTime? CheckedInAt { get; set; } // lúc khách check-in tại rạp

    public DateTime CreatedAt { get; set; }

    public virtual ICollection<BookingSeat> BookingSeats { get; set; } = new List<BookingSeat>();

    public virtual ICollection<BookingConcession> Concessions { get; set; } = new List<BookingConcession>();
}
