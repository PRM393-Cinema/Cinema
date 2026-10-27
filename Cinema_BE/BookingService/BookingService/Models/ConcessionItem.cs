namespace BookingService.Models;

// Món bắp nước / combo bán kèm vé
public class ConcessionItem
{
    public long Id { get; set; }

    public string Name { get; set; } = null!;

    public string? Description { get; set; }

    public decimal Price { get; set; }

    public string? ImageUrl { get; set; }

    // Ngừng bán thì ẩn khỏi app, đơn cũ vẫn giữ tên và giá lúc mua
    public bool Active { get; set; } = true;

    public int SortOrder { get; set; }

    public DateTime CreatedAt { get; set; }
}
