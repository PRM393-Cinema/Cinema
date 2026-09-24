using System.ComponentModel.DataAnnotations;

namespace AuthService.DTOs.Request
{
    public class RefreshTokenRequest
    {
        [Required(ErrorMessage = "Refresh token is required")]
        public string RefreshToken { get; set; } = null!;
    }
}
