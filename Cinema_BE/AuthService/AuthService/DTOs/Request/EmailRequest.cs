using System.ComponentModel.DataAnnotations;
using AuthService.Helpers;

namespace AuthService.DTOs.Request
{
    public class EmailRequest
    {
        [Required(ErrorMessage = "Email is required")]
        [AccountEmail]
        public string Email { get; set; } = null!;
    }
}
