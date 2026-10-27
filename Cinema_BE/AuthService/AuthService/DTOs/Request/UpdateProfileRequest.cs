using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    // Người dùng tự sửa hồ sơ (email không đổi được vì là tên đăng nhập)
    public class UpdateProfileRequest
    {
        [Required(ErrorMessage = "Full name is required")]
        [MaxLength(AccountRules.FullNameMaxLength, ErrorMessage = "Full name must be at most 150 characters")]
        public string FullName { get; set; } = null!;

        // Bỏ trống là xoá số điện thoại
        [AccountPhone]
        public string? Phone { get; set; }
    }
}
