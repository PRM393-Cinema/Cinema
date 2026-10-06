using System;

namespace AuthService.Models;

public partial class RefreshToken
{
    public long Id { get; set; }

    public long UserId { get; set; }

    public string Token { get; set; } = null!;

    public DateTime ExpiresAt { get; set; }

    public bool Revoked { get; set; }

    public User? User { get; set; }
}
