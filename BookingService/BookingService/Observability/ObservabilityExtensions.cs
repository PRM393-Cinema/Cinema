using System.Diagnostics;
using OpenTelemetry.Exporter;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace BookingService.Observability
{
    // Giám sát (SRS §11): metrics cho Prometheus đọc ở /metrics, tracing gửi sang Jaeger qua OTLP,
    // mỗi dòng log kèm TraceId để tra sang trace. Hướng dẫn: docs/MONITORING.md
    public static class ObservabilityExtensions
    {
        public static WebApplicationBuilder AddObservability(
            this WebApplicationBuilder builder,
            string serviceName,
            params string[] meters)
        {
            builder.Logging.Configure(options =>
                options.ActivityTrackingOptions = ActivityTrackingOptions.TraceId | ActivityTrackingOptions.SpanId);

            // Để trống thì không gửi trace (chạy bằng Visual Studio không có Jaeger)
            var tracesEndpoint = builder.Configuration["Observability:OtlpTracesEndpoint"];

            builder.Services.AddOpenTelemetry()
                .ConfigureResource(resource => resource.AddService(serviceName))
                .WithMetrics(metrics => metrics
                    .AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddRuntimeInstrumentation()
                    .AddMeter(meters)
                    .AddPrometheusExporter())
                .WithTracing(tracing =>
                {
                    tracing
                        .SetSampler(new ParentBasedSampler(new SkipBackgroundClientSpansSampler()))
                        .AddAspNetCoreInstrumentation(options =>
                        {
                            options.Filter = context => !IsInfrastructure(context.Request.Path);
                            options.RecordException = true;
                        })
                        .AddHttpClientInstrumentation()
                        // Npgsql và RabbitMQ.Client tự tạo span: thấy câu SQL và message trong trace.
                        // Cinema.*: span của worker gửi event trong outbox lên RabbitMQ
                        .AddSource("Npgsql")
                        .AddSource("RabbitMQ.Client.*")
                        .AddSource("Cinema.*");

                    if (!string.IsNullOrWhiteSpace(tracesEndpoint))
                    {
                        tracing.AddOtlpExporter(options =>
                        {
                            options.Endpoint = new Uri(tracesEndpoint);
                            options.Protocol = OtlpExportProtocol.HttpProtobuf;
                        });
                    }
                });

            return builder;
        }

        // Prometheus đọc metrics ở /metrics (không cần đăng nhập).
        // Có Observability:MetricsPort (Docker) thì chỉ trả trên cổng nội bộ đó, cổng mở ra ngoài trả 404.
        public static WebApplication MapObservability(this WebApplication app)
        {
            var metricsPort = app.Configuration.GetValue<int?>("Observability:MetricsPort");

            app.MapPrometheusScrapingEndpoint(
                    "/metrics",
                    meterProvider: null,
                    configureBranchedPipeline: branch => branch.Use(async (context, next) =>
                    {
                        if (metricsPort is { } port && context.Connection.LocalPort != port)
                        {
                            context.Response.StatusCode = StatusCodes.Status404NotFound;
                            return;
                        }

                        await next(context);
                    }),
                    optionsName: null)
                .AllowAnonymous();

            return app;
        }

        private static bool IsInfrastructure(PathString path)
        {
            return path.StartsWithSegments("/health") ||
                   path.StartsWithSegments("/metrics") ||
                   path.StartsWithSegments("/swagger");
        }

        // Bỏ span gốc của truy vấn DB / gọi HTTP chạy nền (quét outbox mỗi giây, job hết hạn booking,
        // health check của gateway): không thuộc request nào nên mỗi lần quét tạo một trace rời, làm ngập Jaeger.
        // Span nằm trong request / message vẫn được giữ đầy đủ.
        private sealed class SkipBackgroundClientSpansSampler : Sampler
        {
            public override SamplingResult ShouldSample(in SamplingParameters samplingParameters)
            {
                return samplingParameters.ParentContext.TraceId == default &&
                       samplingParameters.Kind == ActivityKind.Client
                    ? new SamplingResult(SamplingDecision.Drop)
                    : new SamplingResult(SamplingDecision.RecordAndSample);
            }
        }
    }
}
