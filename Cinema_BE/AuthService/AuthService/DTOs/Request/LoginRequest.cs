using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    public class LoginRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [AccountEmail]
        public string Email { get; set; } = null!;

        [Required(ErrorMessage = "Password is required")]
        public string Password { get; set; } = null!;
    }
}
