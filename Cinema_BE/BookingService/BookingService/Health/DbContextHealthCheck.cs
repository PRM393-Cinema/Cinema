using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BookingService.Health
{
    // Kiểm tra service còn kết nối được database của DbContext này không (dùng cho /health)
    public sealed class DbContextHealthCheck<TContext> : IHealthCheck where TContext : DbContext
    {
        private readonly TContext _context;

        public DbContextHealthCheck(TContext context)
        {
            _context = context;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            try
            {
                return await _context.Database.CanConnectAsync(cancellationToken)
                    ? HealthCheckResult.Healthy()
                    : HealthCheckResult.Unhealthy("Không kết nối được database.");
            }
            catch (System.Exception ex) when (ex is not OperationCanceledException)
            {
                // Không đưa message của exception ra response (có thể chứa host/port), chỉ ghi log
                return HealthCheckResult.Unhealthy("Không kết nối được database.", ex);
            }
        }
    }
}
