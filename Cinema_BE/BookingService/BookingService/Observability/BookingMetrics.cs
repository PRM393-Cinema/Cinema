using System.Diagnostics.Metrics;

namespace BookingService.Observability
{
    // Metric nghiệp vụ cho Grafana: số booking / payment / hoàn tiền theo trạng thái, số event gửi lên RabbitMQ.
    // Prometheus: cinema_bookings_total{status}, cinema_payments_total{status}, cinema_refunds_total{status},
    // cinema_outbox_published_total{database}, cinema_outbox_publish_failures_total{database}
    public sealed class BookingMetrics
    {
        public const string MeterName = "Cinema.BookingService";

        private readonly Counter<long> _bookings;
        private readonly Counter<long> _payments;
        private readonly Counter<long> _refunds;
        private readonly Counter<long> _outboxPublished;
        private readonly Counter<long> _outboxFailures;

        public BookingMetrics(IMeterFactory meterFactory)
        {
            var meter = meterFactory.Create(MeterName);

            _bookings = meter.CreateCounter<long>("cinema.bookings", description: "Bookings by status change");
            _payments = meter.CreateCounter<long>("cinema.payments", description: "Payments by result");
            _refunds = meter.CreateCounter<long>("cinema.refunds", description: "Refund requests by status");
            _outboxPublished = meter.CreateCounter<long>("cinema.outbox.published", description: "Events published to RabbitMQ");
            _outboxFailures = meter.CreateCounter<long>("cinema.outbox.publish_failures", description: "Failed attempts to publish events");

            // Counter chỉ xuất hiện trong /metrics sau lần tăng đầu tiên, nên Prometheus (increase / rate)
            // bỏ sót lần đó. Tạo sẵn các series bằng 0 để biểu đồ đếm đúng ngay từ booking đầu tiên.
            foreach (var status in new[] { "created", "confirmed", "cancelled", "expired" })
            {
                Booking(status, 0);
            }

            foreach (var status in new[] { "created", "succeeded", "failed" })
            {
                _payments.Add(0, new KeyValuePair<string, object?>("status", status));
            }

            foreach (var status in new[] { "requested", "completed" })
            {
                _refunds.Add(0, new KeyValuePair<string, object?>("status", status));
            }

            foreach (var database in new[] { "BookingDbContext", "PaymentDbContext" })
            {
                OutboxPublished(database, 0);
                _outboxFailures.Add(0, new KeyValuePair<string, object?>("database", database));
            }
        }

        // created / confirmed / cancelled / expired
        public void Booking(string status, int count = 1)
        {
            _bookings.Add(count, new KeyValuePair<string, object?>("status", status));
        }

        // created / succeeded / failed
        public void Payment(string status)
        {
            _payments.Add(1, new KeyValuePair<string, object?>("status", status));
        }

        // requested / completed
        public void Refund(string status)
        {
            _refunds.Add(1, new KeyValuePair<string, object?>("status", status));
        }

        public void OutboxPublished(string database, int count)
        {
            _outboxPublished.Add(count, new KeyValuePair<string, object?>("database", database));
        }

        public void OutboxFailed(string database)
        {
            _outboxFailures.Add(1, new KeyValuePair<string, object?>("database", database));
        }
    }
}
