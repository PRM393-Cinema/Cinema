using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    // Admin tạo tài khoản (vd: nhân viên). Tài khoản dùng được ngay, không cần xác thực email bằng OTP.
    public class CreateUserRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [AccountEmail]
        public string Email { get; set; } = null!;

        [Required(ErrorMessage = "Password is required")]
        [AccountPassword]
        public string Password { get; set; } = null!;

        [Required(ErrorMessage = "Full name is required")]
        [MaxLength(AccountRules.FullNameMaxLength, ErrorMessage = "Full name must be at most 150 characters")]
        public string FullName { get; set; } = null!;

        [AccountPhone]
        public string? Phone { get; set; }

        // Vd: ["ROLE_STAFF"]; viết "STAFF" hay "staff" cũng được
        [Required(ErrorMessage = "Roles are required")]
        [MinLength(1, ErrorMessage = "At least one role is required")]
        public List<string> Roles { get; set; } = new();
    }
}
