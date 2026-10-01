using System.Text;
using AuthService.Configuration;
using AuthService.Data;
using AuthService.Exception;
using AuthService.Repository;
using AuthService.Service;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Npgsql;

// Toàn bộ schema PostgreSQL dùng 'timestamp without time zone' và dữ liệu seed theo giờ local (NOW()).
// Bật legacy behavior để Npgsql chấp nhận DateTime bất kể Kind, tránh lỗi "Cannot write DateTime with Kind=UTC".
AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

var builder = WebApplication.CreateBuilder(args);

//====== DATABASE ======
builder.Services.AddDbContext<AuthDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

//====== JWT OPTIONS ======
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Thiếu cấu hình 'Jwt' trong configuration.");

if (string.IsNullOrWhiteSpace(jwtOptions.SecretKey) || jwtOptions.SecretKey.Length < 32)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey chưa được cấu hình hoặc quá ngắn (cần >= 32 ký tự). " +
        "Hãy đặt bằng User Secrets: dotnet user-secrets set \"Jwt:SecretKey\" \"<khóa bí mật đủ dài>\".");
}

//====== AUTHENTICATION (JWT BEARER) ======
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
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SecretKey)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization();

//====== EMAIL (SMTP) & OTP ======
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));
builder.Services.Configure<OtpOptions>(builder.Configuration.GetSection("Otp"));

//===== REPOSITORY & SERVICE ======
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
builder.Services.AddScoped<IOtpCodeRepository, OtpCodeRepository>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IOtpService, OtpService>();
builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();
builder.Services.AddScoped<IAuthService, AuthService.Service.AuthService>();

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
            Title = "AUTH API",
            Version = "v1",
            Description = "API for Auth Service",
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

// Enable Swagger UI
if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Auth Service API v1");
        c.RoutePrefix = "swagger"; // Truy cập tại: https://localhost:port/swagger
    });

    // Mở http://localhost:<port>/ là vào thẳng Swagger
    app.MapGet("/", () => Results.Redirect("/swagger"))
        .AllowAnonymous()
        .ExcludeFromDescription();
}

// Không redirect sang HTTPS: service chạy sau API Gateway (HTTPS kết thúc ở gateway),
// redirect 307 sẽ khiến client gọi thẳng vào service, đi vòng qua gateway.

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
