using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using MovieService.Configuration;
using MovieService.Data;
using MovieService.Exception;
using MovieService.Health;
using MovieService.Messaging;
using MovieService.Repository.Impl;
using MovieService.Repository.Interface;
using MovieService.Service.Interface;
using ShowtimeService.Data;
using ShowtimeService.Repository.Impl;
using ShowtimeService.Repository.Interface;
using ShowtimeService.Service.Impl;
using ShowtimeService.Service.Interface;

// Schema PostgreSQL dùng 'timestamp without time zone' và dữ liệu seed theo giờ local (NOW()).
// Bật legacy behavior để Npgsql chấp nhận DateTime bất kể Kind, tránh lỗi "Cannot write DateTime with Kind=UTC".
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

var builder = WebApplication.CreateBuilder(args);

//====== DATABASE ======
builder.Services.AddDbContext<MovieDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("MovieDb")));

builder.Services.AddDbContext<ShowtimeDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("ShowtimeDb")));

//===== REPOSITORY & SERVICE======
builder.Services.AddScoped<IMovieRepository, MovieRepository>();
builder.Services.AddScoped<IShowtimeRepository, ShowtimeRepository>();
builder.Services.AddScoped<IRoomRepository, RoomRepository>();
builder.Services.AddScoped<ISeatRepository, SeatRepository>();

builder.Services.AddScoped<IMovieService, MovieService.Service.Impl.MovieService>();
builder.Services.AddScoped<IShowtimeService, ShowtimeService.Service.Impl.ShowtimeService>();
builder.Services.AddScoped<IRoomService, RoomService>();
builder.Services.AddScoped<ISeatService, SeatService>();
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

//====== RABBITMQ: huỷ suất chiếu phát event showtime.cancelled qua outbox (docs/MESSAGING.md) ======
builder.Services
    .AddRabbitMqMessaging(builder.Configuration)
    .AddOutboxPublisher<ShowtimeDbContext>(builder.Configuration);

//====== JWT: tự kiểm tra token do AuthService cấp (lớp bảo vệ thứ hai, phòng khi gọi thẳng vào service, bỏ qua gateway) ======
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Thiếu cấu hình 'Jwt' trong configuration.");

if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey) || jwtOptions.SecretKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey chưa được cấu hình hoặc quá ngắn (cần >= 32 ký tự, giống hệt key của AuthService). " +
        "Hãy đặt bằng User Secrets: dotnet user-secrets set \"Jwt:SecretKey\" \"<key dùng chung>\".");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
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
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(AuthorizationPolicies.AdminOnly,
        policy => policy.RequireRole("ROLE_ADMIN"));

    options.AddPolicy(AuthorizationPolicies.StaffOrAdmin,
        policy => policy.RequireRole("ROLE_STAFF", "ROLE_ADMIN"));

    // Mặc định endpoint nào cũng phải đăng nhập; API công khai phải ghi rõ [AllowAnonymous]
    options.FallbackPolicy = new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build();
});

//====== HEALTH CHECK ======
builder.Services.AddHealthChecks()
    .AddCheck<DbContextHealthCheck<MovieDbContext>>("movie-db", timeout: TimeSpan.FromSeconds(5))
    .AddCheck<DbContextHealthCheck<ShowtimeDbContext>>("showtime-db", timeout: TimeSpan.FromSeconds(5))
    // RabbitMQ dừng chỉ báo Degraded: event chờ trong outbox
    .AddCheck<RabbitMqHealthCheck>("rabbitmq", timeout: TimeSpan.FromSeconds(5));

// Add services to the container.

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
            Title = "CINEMA API",
            Version = "v1",
            Description = "API for Cinema Service",
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
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Cinema Service API v1");
        c.RoutePrefix = "swagger"; // Truy cập tại: https://localhost:port/swagger
    });

    // Mở http://localhost:<port>/ là vào thẳng Swagger (AllowAnonymous vì mặc định mọi endpoint cần đăng nhập)
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

// /health: kiểm tra kết nối database. /health/live: chỉ báo tiến trình còn chạy (gateway dùng để biết service sống hay chết).
// AllowAnonymous vì mặc định mọi endpoint của MovieService đều cần đăng nhập.
app.MapHealthChecks("/health", new HealthCheckOptions { ResponseWriter = HealthResponseWriter.WriteAsync })
    .AllowAnonymous();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false, ResponseWriter = HealthResponseWriter.WriteAsync })
    .AllowAnonymous();

app.Run();

// Cho project test (WebApplicationFactory<Program>) dựng service trong bộ nhớ
public partial class Program { }
