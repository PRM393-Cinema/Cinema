namespace MovieService.Configuration
{
    // Phải trùng Issuer / Audience / SecretKey với AuthService (key dùng chung cho cả hệ thống)
    public class JwtOptions
    {
        public string Issuer { get; set; } = null!;

        public string Audience { get; set; } = null!;

        public string SecretKey { get; set; } = null!;
    }
}
