using BookingService.Messaging;
using BookingService.Models;
using BookingService.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace BookingService.Health
{
    // RabbitMQ dừng: service vẫn nhận đặt vé / thanh toán bình thường (event chờ trong outbox),
    // nên báo Degraded chứ không Unhealthy. Kèm số event đang chờ gửi để biết RabbitMQ dừng bao lâu.
    public sealed class RabbitMqHealthCheck : IHealthCheck
    {
        private readonly RabbitMqConnection _rabbitMq;
        private readonly BookingDbContext _bookingDb;
        private readonly PaymentDbContext _paymentDb;

        public RabbitMqHealthCheck(
            RabbitMqConnection rabbitMq,
            BookingDbContext bookingDb,
            PaymentDbContext paymentDb)
        {
            _rabbitMq = rabbitMq;
            _bookingDb = bookingDb;
            _paymentDb = paymentDb;
        }

        public async Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            var data = new Dictionary<string, object>();

            try
            {
                data["pendingBookingEvents"] = await _bookingDb.Set<OutboxMessage>()
                    .CountAsync(message => message.PublishedAt == null, cancellationToken);
                data["pendingPaymentEvents"] = await _paymentDb.Set<OutboxMessage>()
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
            catch (Exception ex)
            {
                return HealthCheckResult.Degraded(
                    "RabbitMQ is unreachable, events wait in the outbox.",
                    ex,
                    data);
            }
        }
    }
}
