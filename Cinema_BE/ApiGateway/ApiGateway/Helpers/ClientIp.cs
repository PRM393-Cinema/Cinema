using System.Net;

namespace ApiGateway.Helpers
{
    // IP của khách để chia hạn mức request. Sau proxy (Render + Cloudflare), RemoteIpAddress là IP của proxy,
    // nên mọi người dùng chung một hạn mức: khi đó đọc IP thật từ header mà proxy ghi (RateLimiting:ClientIpHeader).
    public static class ClientIp
    {
        public static string Resolve(HttpContext context, string? header)
        {
            // Header không có hoặc không phải một IP hợp lệ: dùng IP kết nối như khi chạy không có proxy
            if (!string.IsNullOrWhiteSpace(header) &&
                IPAddress.TryParse(context.Request.Headers[header].ToString().Trim(), out var forwarded))
            {
                return forwarded.ToString();
            }

            return context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        }
    }
}
