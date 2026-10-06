using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    // false = khoá tài khoản (không đăng nhập được), true = mở lại
    public class UpdateUserStatusRequest
    {
        [Required(ErrorMessage = "Enabled is required")]
        public bool? Enabled { get; set; }
    }
}
