using System;

namespace AuthService.Models;

public partial class OtpCode
{
    public long Id { get; set; }

    public long UserId { get; set; }

    public string Purpose { get; set; } = null!;

    public string CodeHash { get; set; } = null!;

    public DateTime ExpiresAt { get; set; }

    public int Attempts { get; set; }

    public DateTime CreatedAt { get; set; }

    public User? User { get; set; }
}
