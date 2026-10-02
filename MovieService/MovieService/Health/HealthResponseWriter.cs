using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace MovieService.Health
{
    // Kết quả /health dạng JSON: trạng thái chung và từng mục kiểm tra
    public static class HealthResponseWriter
    {
        public static Task WriteAsync(HttpContext context, HealthReport report)
        {
            return context.Response.WriteAsJsonAsync(new
            {
                status = report.Status.ToString(),
                totalDurationMs = (int)report.TotalDuration.TotalMilliseconds,
                checks = report.Entries.Select(entry => new
                {
                    name = entry.Key,
                    status = entry.Value.Status.ToString(),
                    durationMs = (int)entry.Value.Duration.TotalMilliseconds,
                    error = entry.Value.Status == HealthStatus.Healthy ? null : entry.Value.Description
                })
            });
        }
    }
}
