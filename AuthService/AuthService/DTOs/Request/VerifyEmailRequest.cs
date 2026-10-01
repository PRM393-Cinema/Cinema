using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    public class VerifyEmailRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email is not valid")]
        public string Email { get; set; } = null!;

        [Required(ErrorMessage = "OTP is required")]
        [RegularExpression(@"^\d{6}$", ErrorMessage = "OTP must be 6 digits")]
        public string Otp { get; set; } = null!;

        // Mật khẩu đã dùng khi đăng ký. OTP chỉ kích hoạt tài khoản khi đi kèm đúng mật khẩu,
        // để người khác không thể đăng ký trước bằng email của mình rồi chiếm tài khoản sau khi mình xác thực.
        [Required(ErrorMessage = "Password is required")]
        public string Password { get; set; } = null!;
    }
}
