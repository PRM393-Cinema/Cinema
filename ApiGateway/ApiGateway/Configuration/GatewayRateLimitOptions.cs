namespace ApiGateway.Configuration
{
    public class GatewayRateLimitOptions
    {
        // Tên policy dùng trong ReverseProxy:Routes:*:RateLimiterPolicy
        public const string AuthPolicy = "auth";

        // Giới hạn chung cho mọi request, tính theo IP
        public int PermitLimit { get; set; } = 100;

        public int WindowSeconds { get; set; } = 60;

        // Giới hạn chặt hơn cho đăng ký / đăng nhập / refresh (chống dò mật khẩu)
        public int AuthPermitLimit { get; set; } = 10;

        public int AuthWindowSeconds { get; set; } = 60;
    }
}
