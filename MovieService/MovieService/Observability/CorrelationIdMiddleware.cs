using System.Diagnostics;

namespace MovieService.Observability
{
    // Gateway gắn X-Correlation-ID cho mọi request và chuyển tiếp xuống service.
    // Middleware này đưa id đó vào log (scope CorrelationId) và vào span của trace để tra cứu chung.
    public sealed class CorrelationIdMiddleware
    {
        public const string HeaderName = "X-Correlation-ID";

        private const int MaxLength = 128;

        private readonly RequestDelegate _next;
        private readonly ILogger<CorrelationIdMiddleware> _logger;

        public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var incoming = context.Request.Headers[HeaderName].ToString();

            // Gọi thẳng vào service (không qua gateway) thì dùng TraceId làm correlation id
            var correlationId = IsValid(incoming)
                ? incoming
                : Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier;

            Activity.Current?.SetTag("correlation.id", correlationId);

            using (_logger.BeginScope("CorrelationId:{CorrelationId}", correlationId))
            {
                await _next(context);
            }
        }

        private static bool IsValid(string value)
        {
            return !string.IsNullOrWhiteSpace(value) &&
                   value.Length <= MaxLength &&
                   value.All(c => char.IsLetterOrDigit(c) || c is '-' or '_' or '.');
        }
    }
}
