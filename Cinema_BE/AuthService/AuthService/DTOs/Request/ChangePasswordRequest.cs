using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    // Đổi mật khẩu khi còn nhớ mật khẩu hiện tại (quên mật khẩu thì dùng luồng OTP)
    public class ChangePasswordRequest
    {
        [Required(ErrorMessage = "Current password is required")]
        public string CurrentPassword { get; set; } = null!;

        [Required(ErrorMessage = "New password is required")]
        [AccountPassword]
        public string NewPassword { get; set; } = null!;
    }
}
