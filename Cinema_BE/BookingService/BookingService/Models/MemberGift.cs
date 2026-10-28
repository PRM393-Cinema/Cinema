namespace BookingService.Models;

public class MemberGift
{
    public long UserId { get; set; }
    public string Tier { get; set; } = "VIP";
    public DateTime RenewsAt { get; set; }
    public int Tickets { get; set; }
    public int Combos { get; set; }
}

public class MemberGiftUse
{
    public long BookingId { get; set; }
    public long UserId { get; set; }
    public DateTime RenewsAt { get; set; }
    public int Tickets { get; set; }
    public int Combos { get; set; }
    public decimal Discount { get; set; }
}
