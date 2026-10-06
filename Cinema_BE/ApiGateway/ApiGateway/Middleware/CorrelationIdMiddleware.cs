namespace ApiGateway.Middleware
{
    // Gắn correlation id cho mọi request: dùng lại id client gửi lên (nếu hợp lệ) hoặc tạo mới,
    // chuyển tiếp xuống service phía sau và trả về trong response để trace request.
    public class CorrelationIdMiddleware
    {
        public const string HeaderName = "X-Correlation-ID";

        public const string ItemKey = "CorrelationId";

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
            var correlationId = IsValid(incoming) ? incoming : Guid.NewGuid().ToString();

            context.Items[ItemKey] = correlationId;

            // Gắn vào span của trace: tìm trong Jaeger theo tag correlation.id
            System.Diagnostics.Activity.Current?.SetTag("correlation.id", correlationId);

            // Header này được YARP chuyển tiếp nguyên vẹn xuống service phía sau
            context.Request.Headers[HeaderName] = correlationId;

            context.Response.OnStarting(() =>
            {
                context.Response.Headers[HeaderName] = correlationId;
                return Task.CompletedTask;
            });

            // Scope dạng message template: log thường in "CorrelationId:abc", log JSON có thuộc tính CorrelationId
            using (_logger.BeginScope("CorrelationId:{CorrelationId}", correlationId))
            {
                await _next(context);
            }
        }

        private static bool IsValid(string value) =>
            !string.IsNullOrWhiteSpace(value)
            && value.Length <= MaxLength
            && value.All(c => char.IsLetterOrDigit(c) || c is '-' or '_' or '.');
    }
}
