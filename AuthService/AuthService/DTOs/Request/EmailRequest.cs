using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    public class EmailRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email is not valid")]
        public string Email { get; set; } = null!;
    }
}
