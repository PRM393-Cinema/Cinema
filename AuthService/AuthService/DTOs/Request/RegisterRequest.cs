using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    public class RegisterRequest
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
    }
}
