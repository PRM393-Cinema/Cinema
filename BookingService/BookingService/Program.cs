using System.Text;
using BookingService.Data;
using BookingService.Clients.Implementations;
using BookingService.Clients.Interfaces;
using BookingService.Configuration;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Repositories.Impl;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Implementations;
using BookingService.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
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
});

builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();

builder.Services.AddHttpClient<IShowtimeClient, ShowtimeClient>(client =>
{
    var baseUrl = builder.Configuration["ShowtimeService:BaseUrl"];

    if (string.IsNullOrWhiteSpace(baseUrl))
    {
        throw new InvalidOperationException(
            "ShowtimeService:BaseUrl is not configured.");
    }

    client.BaseAddress = new Uri(baseUrl);
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
});

builder.Services.AddScoped<IBookingRepository, BookingRepository>();
builder.Services.AddScoped<IBookingSeatRepository, BookingSeatRepository>();
builder.Services.AddScoped<ISeatReservationRepository, SeatReservationRepository>();
builder.Services.AddScoped<INotificationRepository, NotificationRepository>();
builder.Services.AddScoped<IPaymentRepository, PaymentRepository>();

builder.Services.AddScoped<IBookingService, BookingService.Services.Implementations.BookingService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();


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
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
