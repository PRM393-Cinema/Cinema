using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    // Admin tạo tài khoản (vd: nhân viên). Tài khoản dùng được ngay, không cần xác thực email bằng OTP.
    public class CreateUserRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email is not valid")]
        public string Email { get; set; } = null!;

        [Required(ErrorMessage = "Password is required")]
        [MinLength(6, ErrorMessage = "Password must be at least 6 characters")]
        public string Password { get; set; } = null!;

        [Required(ErrorMessage = "Full name is required")]
        [MaxLength(150)]
        public string FullName { get; set; } = null!;

        [Phone(ErrorMessage = "Phone number is not valid")]
        [MaxLength(20)]
        public string? Phone { get; set; }

        // Vd: ["ROLE_STAFF"]; viết "STAFF" hay "staff" cũng được
        [Required(ErrorMessage = "Roles are required")]
        [MinLength(1, ErrorMessage = "At least one role is required")]
        public List<string> Roles { get; set; } = new();
    }
}
