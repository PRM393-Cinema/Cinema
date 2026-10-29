using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    public class RegisterRequest
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
    }
}
