namespace AuthService.Configuration
{
    public class JwtOptions
    {
        public string Issuer { get; set; } = null!;

        public string Audience { get; set; } = null!;

        public string SecretKey { get; set; } = null!;

        public int AccessTokenMinutes { get; set; } = 60;

        public int RefreshTokenDays { get; set; } = 7;
    }
}
