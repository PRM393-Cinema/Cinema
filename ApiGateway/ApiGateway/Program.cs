using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using ApiGateway.Configuration;
using ApiGateway.Helpers;
using ApiGateway.Middleware;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Yarp.ReverseProxy.Forwarder;

var builder = WebApplication.CreateBuilder(args);

//====== JWT (dùng chung Issuer / Audience / SecretKey với AuthService) ======
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Thiếu cấu hình 'Jwt' trong configuration.");

if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey) || jwtOptions.SecretKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey chưa được cấu hình hoặc quá ngắn (cần >= 32 ký tự, giống hệt AuthService). " +
        "Hãy đặt bằng User Secrets: dotnet user-secrets set \"Jwt:SecretKey\" \"<khóa của AuthService>\".");
}

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
            ClockSkew = TimeSpan.Zero,
            RoleClaimType = ClaimTypes.Role
        };

        // Trả 401 / 403 dạng ProblemDetails thay vì body rỗng
        options.Events = new JwtBearerEvents
        {
            OnChallenge = context =>
            {
                context.HandleResponse();

                var detail = context.AuthenticateFailure is null
                    ? "Bạn cần đăng nhập để truy cập tài nguyên này."
                    : "Token không hợp lệ hoặc đã hết hạn.";

                return GatewayProblem.WriteAsync(
                    context.HttpContext, StatusCodes.Status401Unauthorized, "Unauthorized", detail);
            },
            OnForbidden = context => GatewayProblem.WriteAsync(
                context.HttpContext, StatusCodes.Status403Forbidden, "Forbidden",
                "Bạn không có quyền truy cập tài nguyên này.")
        };
    });

//====== AUTHORIZATION: policy được gắn vào từng route trong ReverseProxy:Routes ======
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(AuthorizationPolicies.AdminOnly,
        policy => policy.RequireRole("ROLE_ADMIN"));

    options.AddPolicy(AuthorizationPolicies.StaffOrAdmin,
        policy => policy.RequireRole("ROLE_STAFF", "ROLE_ADMIN"));
});

//====== RATE LIMITING (theo IP) ======
var rateLimit = builder.Configuration.GetSection("RateLimiting").Get<GatewayRateLimitOptions>()
    ?? new GatewayRateLimitOptions();

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(GetClientIp(context), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = rateLimit.PermitLimit,
            Window = TimeSpan.FromSeconds(rateLimit.WindowSeconds),
            QueueLimit = 0
        }));

    options.AddPolicy(GatewayRateLimitOptions.AuthPolicy, context =>
        RateLimitPartition.GetFixedWindowLimiter(GetClientIp(context), _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = rateLimit.AuthPermitLimit,
            Window = TimeSpan.FromSeconds(rateLimit.AuthWindowSeconds),
            QueueLimit = 0
        }));

    options.OnRejected = (context, _) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            context.HttpContext.Response.Headers.RetryAfter = ((int)retryAfter.TotalSeconds).ToString();
        }

        return new ValueTask(GatewayProblem.WriteAsync(
            context.HttpContext, StatusCodes.Status429TooManyRequests, "Too Many Requests",
            "Bạn gửi quá nhiều yêu cầu, vui lòng thử lại sau."));
    };
});

//====== CORS (Flutter web / công cụ test chạy trên trình duyệt) ======
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? Array.Empty<string>();

builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
{
    if (allowedOrigins.Length > 0)
    {
        policy.WithOrigins(allowedOrigins);
    }
    else
    {
        policy.AllowAnyOrigin();
    }

    policy.AllowAnyHeader()
        .AllowAnyMethod()
        .WithExposedHeaders(CorrelationIdMiddleware.HeaderName, "Retry-After");
}));

builder.Services.AddHealthChecks();

//====== REVERSE PROXY (YARP): route + cluster đọc từ ReverseProxy trong appsettings.json ======
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

var app = builder.Build();

app.UseMiddleware<CorrelationIdMiddleware>();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Ok(new { service = "Cinema API Gateway", health = "/health" }));
app.MapHealthChecks("/health");

app.MapReverseProxy(proxyPipeline =>
{
    // Service phía sau không phản hồi -> trả 503 / 504 dạng ProblemDetails thay vì 502 rỗng
    proxyPipeline.Use(async (context, next) =>
    {
        await next();

        if (context.GetForwarderErrorFeature() is null || context.Response.HasStarted)
        {
            return;
        }

        if (context.Response.StatusCode == StatusCodes.Status504GatewayTimeout)
        {
            await GatewayProblem.WriteAsync(context, StatusCodes.Status504GatewayTimeout, "Gateway Timeout",
                "Service phía sau xử lý quá thời gian cho phép.");
        }
        else if (context.Response.StatusCode is StatusCodes.Status502BadGateway or StatusCodes.Status503ServiceUnavailable)
        {
            await GatewayProblem.WriteAsync(context, StatusCodes.Status503ServiceUnavailable, "Service Unavailable",
                "Service phía sau đang không khả dụng, vui lòng thử lại sau.");
        }
    });

    proxyPipeline.UseSessionAffinity();
    proxyPipeline.UseLoadBalancing();
    proxyPipeline.UsePassiveHealthChecks();
});

app.Run();

static string GetClientIp(HttpContext context) =>
    context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
