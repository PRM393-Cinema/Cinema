namespace BookingService.Models;

// Một dòng bắp nước trong đơn: lưu lại tên và giá lúc mua
public class BookingConcession
{
    public long Id { get; set; }

    public long BookingId { get; set; }

    public long ItemId { get; set; }

    public string ItemName { get; set; } = null!;

    public decimal UnitPrice { get; set; }

    public int Quantity { get; set; }

    public virtual Booking Booking { get; set; } = null!;
}
