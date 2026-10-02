using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    // Danh sách role mới, thay toàn bộ role cũ. Vd: ["ROLE_ADMIN", "ROLE_STAFF"]
    public class UpdateUserRolesRequest
    {
        [Required(ErrorMessage = "Roles are required")]
        [MinLength(1, ErrorMessage = "At least one role is required")]
        public List<string> Roles { get; set; } = new();
    }
}
