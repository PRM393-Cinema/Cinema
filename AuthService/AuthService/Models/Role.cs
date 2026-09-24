using System;
using System.Collections.Generic;

namespace AuthService.Models;

public partial class Role
{
    public long RoleId { get; set; }

    public string Name { get; set; } = null!;

    public ICollection<User> Users { get; set; } = new List<User>();
}
