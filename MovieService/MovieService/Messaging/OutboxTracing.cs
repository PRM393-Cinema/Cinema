using System.Diagnostics;
using System.Text.Json;

namespace MovieService.Messaging
{
    // Nối trace qua RabbitMQ: event lưu traceparent của request tạo ra nó, worker gửi event mở span con
    // của trace đó. RabbitMQ.Client chuyển tiếp trace qua header nên consumer cũng nằm trong cùng trace.
    public static class OutboxTracing
    {
        public const string SourceName = "Cinema.Outbox";

        private static readonly ActivitySource Source = new(SourceName);

        // W3C traceparent của request / message đang xử lý (null nếu không có trace)
        public static string? CurrentTraceParent()
        {
            return Activity.Current?.Id;
        }

        public static Activity? StartPublish(OutboxMessage message)
        {
            ActivityContext parent = default;

            try
            {
                using var document = JsonDocument.Parse(message.Payload);

                if (document.RootElement.TryGetProperty("traceParent", out var traceParent) &&
                    traceParent.ValueKind == JsonValueKind.String)
                {
                    ActivityContext.TryParse(traceParent.GetString(), null, isRemote: true, out parent);
                }
            }
            catch (JsonException)
            {
                // Payload hỏng: gửi như event không có trace
            }

            var activity = Source.StartActivity($"outbox {message.EventType}", ActivityKind.Internal, parent);
            activity?.SetTag("messaging.message.id", message.EventId);

            return activity;
        }
    }
}
