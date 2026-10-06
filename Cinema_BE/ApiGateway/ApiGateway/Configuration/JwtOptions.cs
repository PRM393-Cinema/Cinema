namespace ApiGateway.Configuration
{
    // Phải trùng Issuer / Audience / SecretKey với AuthService để validate được token
    public class JwtOptions
    {
        public string Issuer { get; set; } = null!;

        public string Audience { get; set; } = null!;

        public string SecretKey { get; set; } = null!;
    }
}
