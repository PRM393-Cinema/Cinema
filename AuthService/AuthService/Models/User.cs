using System;
using System.Collections.Generic;

namespace AuthService.Models;

public partial class User
{
    public long UserId { get; set; }

    public string Email { get; set; } = null!;

    public string PasswordHash { get; set; } = null!;

    public string? FullName { get; set; }

    public string? Phone { get; set; }

    public bool Enabled { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public ICollection<Role> Roles { get; set; } = new List<Role>();

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}
