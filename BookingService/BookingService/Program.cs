using System.Text;
using BookingService.Data;
using BookingService.Clients.Handlers;
using BookingService.Clients.Implementations;
using BookingService.Clients.Interfaces;
using BookingService.Configuration;
using BookingService.Exceptions;
using BookingService.Health;
using BookingService.Helpers;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using BookingService.Repositories.Impl;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Implementations;
using BookingService.Services.Interfaces;
using BookingService.Workers;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Http.Resilience;
using Polly;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

// Schema PostgreSQL dùng 'timestamp without time zone' và dữ liệu seed theo giờ local (NOW()).
// Bật legacy behavior để Npgsql chấp nhận DateTime bất kể Kind, tránh lỗi "Cannot write DateTime with Kind=UTC".
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

var builder = WebApplication.CreateBuilder(args);

//====== DATABASE ======
builder.Services.AddDbContext<BookingDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("BookingDb")));

builder.Services.AddDbContext<NotificationDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("NotificationDb")));

builder.Services.AddDbContext<PaymentDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("PaymentDb")));

//===== REPOSITORY & SERVICE======

builder.Services.AddScoped<TransactionManager>();

builder.Services.Configure<PayOsOptions>(
    builder.Configuration.GetSection("PayOS"));
builder.Services.Configure<SmtpOptions>(
    builder.Configuration.GetSection("Smtp"));

builder.Services.Configure<JwtOptions>(
    builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<BookingExpiryOptions>(
    builder.Configuration.GetSection("BookingExpiry"));
builder.Services.Configure<RefundPolicyOptions>(
    builder.Configuration.GetSection("RefundPolicy"));

var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException(
        "Missing Jwt configuration.");

if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey) ||
    jwtOptions.SecretKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey must be configured with at least 32 characters.");
}

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
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
        IssuerSigningKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
        ClockSkew = TimeSpan.Zero,
        RoleClaimType = System.Security.Claims.ClaimTypes.Role
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(
        AuthorizationPolicies.UserOrStaff,
        policy => policy.RequireRole(
            "USER", "ROLE_USER", "ROLE_CUSTOMER",
            "STAFF", "ROLE_STAFF", "ADMIN", "ROLE_ADMIN"));

    options.AddPolicy(
        AuthorizationPolicies.StaffOrAdmin,
        policy => policy.RequireRole(
            "STAFF", "ROLE_STAFF", "ADMIN", "ROLE_ADMIN"));

    options.AddPolicy(
        AuthorizationPolicies.AnyRole,
        policy => policy.RequireRole(
            "USER", "ROLE_USER", "ROLE_CUSTOMER",
            "STAFF", "ROLE_STAFF", "ADMIN", "ROLE_ADMIN"));

    options.AddPolicy(
        AuthorizationPolicies.AdminOnly,
        policy => policy.RequireRole("ADMIN", "ROLE_ADMIN"));
});

builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();

// MovieService yêu cầu JWT: gọi sang đó kèm token của người dùng đang thao tác
builder.Services.AddHttpContextAccessor();
builder.Services.AddTransient<ForwardAuthorizationHandler>();

builder.Services.AddHttpClient<IShowtimeClient, ShowtimeClient>(client =>
{
    var baseUrl = builder.Configuration["ShowtimeService:BaseUrl"];

    if (string.IsNullOrWhiteSpace(baseUrl))
    {
        throw new InvalidOperationException(
            "ShowtimeService:BaseUrl is not configured.");
    }

    client.BaseAddress = new Uri(baseUrl);
})
.AddHttpMessageHandler<ForwardAuthorizationHandler>()
// Retry + Circuit Breaker + timeout (SRS §13.2). Lời gọi lấy giá ghế chỉ đọc dữ liệu nên retry an toàn.
// Lỗi liên tục: circuit mở 15 giây, trả 503 ngay thay vì chờ từng request bị timeout.
.AddStandardResilienceHandler(options =>
{
    options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(12);
    options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(3);
    options.Retry.MaxRetryAttempts = 2;
    options.Retry.Delay = TimeSpan.FromMilliseconds(300);
    options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
    options.CircuitBreaker.MinimumThroughput = 5;
    options.CircuitBreaker.FailureRatio = 0.5;
    options.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(15);
});

builder.Services.AddHttpClient<IPayOsClient, PayOsClient>(client =>
{
    var baseUrl = builder.Configuration["PayOS:BaseUrl"];

    if (string.IsNullOrWhiteSpace(baseUrl))
    {
        throw new InvalidOperationException(
            "PayOS:BaseUrl is not configured.");
    }

    client.BaseAddress = new Uri(baseUrl);
})
// PayOS: chỉ retry lời gọi đọc (GET trạng thái thanh toán). Tạo link thanh toán (POST) không retry,
// vì lần đầu có thể đã thành công phía PayOS dù mình không nhận được phản hồi.
.AddStandardResilienceHandler(options =>
{
    options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(20);
    options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(8);
    options.Retry.MaxRetryAttempts = 2;
    options.Retry.Delay = TimeSpan.FromMilliseconds(500);
    options.Retry.ShouldHandle = args => ValueTask.FromResult(
        args.Context.GetRequestMessage()?.Method == HttpMethod.Get &&
        HttpClientResiliencePredicates.IsTransient(args.Outcome));
    options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(30);
    options.CircuitBreaker.MinimumThroughput = 5;
    options.CircuitBreaker.FailureRatio = 0.5;
    options.CircuitBreaker.BreakDuration = TimeSpan.FromSeconds(15);
});

builder.Services.AddScoped<IBookingRepository, BookingRepository>();
builder.Services.AddScoped<IBookingSeatRepository, BookingSeatRepository>();
builder.Services.AddScoped<ISeatReservationRepository, SeatReservationRepository>();
builder.Services.AddScoped<INotificationRepository, NotificationRepository>();
builder.Services.AddScoped<IPaymentRepository, PaymentRepository>();
builder.Services.AddScoped<IRefundRepository, RefundRepository>();

builder.Services.AddScoped<IBookingService, BookingService.Services.Implementations.BookingService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IRefundService, RefundService>();

// Job nền: booking PENDING quá 10 phút chưa thanh toán -> EXPIRED, nhả ghế
builder.Services.AddHostedService<BookingExpiryWorker>();

//====== RABBITMQ (SRS §13.1): outbox + publisher + consumer, chi tiết docs/MESSAGING.md ======
builder.Services
    .AddRabbitMqMessaging(builder.Configuration)
    // Gửi event đã ghi trong outbox của 2 database lên RabbitMQ
    .AddOutboxPublisher<BookingDbContext>(builder.Configuration)
    .AddOutboxPublisher<PaymentDbContext>(builder.Configuration)
    // Gửi email cho khách theo event (FR-NOTI-06)
    .AddEventConsumer<NotificationEventHandler>(
        builder.Configuration,
        "booking-service.notifications",
        "booking.*", "payment.*")
    // Booking hết hạn / bị huỷ: cập nhật payment, tạo yêu cầu hoàn tiền
    .AddEventConsumer<PaymentBookingEventsHandler>(
        builder.Configuration,
        "booking-service.payment-updates",
        EventTypes.BookingCancelled, EventTypes.BookingExpired)
    // MovieService huỷ suất chiếu: huỷ các booking của suất đó
    .AddEventConsumer<ShowtimeCancelledHandler>(
        builder.Configuration,
        "booking-service.showtime-cancelled",
        EventTypes.ShowtimeCancelled);

//====== HEALTH CHECK ======
builder.Services.AddHealthChecks()
    .AddCheck<DbContextHealthCheck<BookingDbContext>>("booking-db", timeout: TimeSpan.FromSeconds(5))
    .AddCheck<DbContextHealthCheck<PaymentDbContext>>("payment-db", timeout: TimeSpan.FromSeconds(5))
    .AddCheck<DbContextHealthCheck<NotificationDbContext>>("notification-db", timeout: TimeSpan.FromSeconds(5))
    // RabbitMQ dừng chỉ báo Degraded: đặt vé / thanh toán vẫn chạy, event chờ trong outbox
    .AddCheck<RabbitMqHealthCheck>("rabbitmq", timeout: TimeSpan.FromSeconds(5));

builder.Services.AddControllers();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc(
        "v1",
        new()
        {
            Title = "BOOKING API",
            Version = "v1",
            Description = "API for Booking Service",
        });

    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            In = ParameterLocation.Header,
            Description = "Enter JWT token: Bearer {token}"
        });

    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference =
                        new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Bearer"
                        }
                },
                Array.Empty<string>()
            }
        });
});

var app = builder.Build();

app.UseExceptionHandler();

// Enable Swagger UI (Bật cho cả môi trường Dev và Production nếu cần test)
if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Booking Service API v1");
        c.RoutePrefix = "swagger"; // Truy cập tại: https://localhost:port/swagger
    });

    // Mở http://localhost:<port>/ là vào thẳng Swagger
    app.MapGet("/", () => Results.Redirect("/swagger"))
        .AllowAnonymous()
        .ExcludeFromDescription();
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Không redirect sang HTTPS: service chạy sau API Gateway (HTTPS kết thúc ở gateway),
// redirect 307 sẽ khiến client gọi thẳng vào service, đi vòng qua gateway.

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// /health: kiểm tra kết nối database. /health/live: chỉ báo tiến trình còn chạy (gateway dùng để biết service sống hay chết)
app.MapHealthChecks("/health", new HealthCheckOptions { ResponseWriter = HealthResponseWriter.WriteAsync })
    .AllowAnonymous();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false, ResponseWriter = HealthResponseWriter.WriteAsync })
    .AllowAnonymous();

app.Run();
