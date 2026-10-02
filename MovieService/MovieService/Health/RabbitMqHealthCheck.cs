using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using MovieService.Messaging;
using ShowtimeService.Data;

namespace MovieService.Health
{
    // RabbitMQ dừng: huỷ suất chiếu vẫn chạy (event chờ trong outbox), nên báo Degraded chứ không Unhealthy
    public sealed class RabbitMqHealthCheck : IHealthCheck
    {
        private readonly RabbitMqConnection _rabbitMq;
        private readonly ShowtimeDbContext _showtimeDb;

        public RabbitMqHealthCheck(RabbitMqConnection rabbitMq, ShowtimeDbContext showtimeDb)
        {
            _rabbitMq = rabbitMq;
            _showtimeDb = showtimeDb;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            var data = new Dictionary<string, object>();

            try
            {
                data["pendingShowtimeEvents"] = await _showtimeDb.Set<OutboxMessage>()
                    .CountAsync(message => message.PublishedAt == null, cancellationToken);
            }
            catch
            {
                // Lỗi database đã có health check riêng báo
            }

            if (!_rabbitMq.Options.Enabled)
            {
                return HealthCheckResult.Degraded("RabbitMQ is disabled (RabbitMq:Enabled = false).", data: data);
            }

            try
            {
                await _rabbitMq.GetConnectionAsync(cancellationToken);
                return HealthCheckResult.Healthy("Connected to RabbitMQ.", data);
            }
            catch (System.Exception ex)
            {
                return HealthCheckResult.Degraded(
                    "RabbitMQ is unreachable, events wait in the outbox.",
                    ex,
                    data);
            }
        }
    }
}
