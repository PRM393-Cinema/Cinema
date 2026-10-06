using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using AuthService.Data;
using AuthService.DTOs;
using AuthService.Models;
using AuthService.Service;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Testcontainers.PostgreSql;

namespace AuthService.Tests.Infrastructure;

// AuthService chạy trong bộ nhớ với PostgreSQL thật (container); email gửi vào FakeEmailSender
public class AuthApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string AdminEmail = "admin@test.local";
    public const string AdminPassword = "Admin@123";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine").Build();

    public FakeEmailSender Emails { get; } = new();

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        var options = new DbContextOptionsBuilder<AuthDbContext>()
            .UseNpgsql(ConnectionString())
            .Options;

        await using var db = new AuthDbContext(options);
        await db.Database.EnsureCreatedAsync();

        var roles = new[] { "ROLE_ADMIN", "ROLE_STAFF", "ROLE_CUSTOMER" }
            .Select(name => new Role { Name = name })
            .ToList();

        db.Roles.AddRange(roles);
        db.Users.Add(new User
        {
            Email = AdminEmail,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(AdminPassword),
            FullName = "Quản trị viên",
            Enabled = true,
            EmailVerified = true,
            CreatedAt = DateTime.Now,
            Roles = new List<Role> { roles[0] }
        });

        await db.SaveChangesAsync();
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        await _postgres.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Logging:LogLevel:Default", "Warning");
        builder.UseSetting("Logging:LogLevel:Microsoft.EntityFrameworkCore", "Warning");
        builder.UseSetting("ConnectionStrings:DefaultConnection", ConnectionString());
        builder.UseSetting("Jwt:SecretKey", TestJwt.SecretKey);

        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IEmailSender>();
            services.AddSingleton<IEmailSender>(Emails);
        });
    }

    public HttpClient ClientFor(string? token)
    {
        var client = CreateClient();

        if (token != null)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return client;
    }

    public async Task<JsonElement> LoginAsync(string email, string password)
    {
        var response = await CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { email, password });
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    public async Task<string> AdminTokenAsync()
    {
        return (await LoginAsync(AdminEmail, AdminPassword)).GetProperty("accessToken").GetString()!;
    }

    // Đăng ký + nhập OTP: trả về phản hồi đăng nhập của tài khoản khách mới
    public async Task<JsonElement> RegisterVerifiedCustomerAsync(string email, string password)
    {
        var client = CreateClient();

        (await client.PostAsJsonAsync("/api/v1/auth/register",
            new { email, password, fullName = "Khách Test", phone = "0900000000" })).EnsureSuccessStatusCode();

        var verify = await client.PostAsJsonAsync("/api/v1/auth/verify-email",
            new { email, otp = Emails.LatestOtp(email), password });
        verify.EnsureSuccessStatusCode();

        return await verify.Content.ReadFromJsonAsync<JsonElement>();
    }

    private string ConnectionString()
    {
        return new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
        {
            Database = "cinema_auth_test"
        }.ConnectionString;
    }
}

public sealed class FakeEmailSender : IEmailSender
{
    private readonly ConcurrentQueue<EmailMessage> _sent = new();

    public Task SendAsync(EmailMessage email, CancellationToken cancellationToken = default)
    {
        _sent.Enqueue(email);
        return Task.CompletedTask;
    }

    public List<EmailMessage> To(string recipient)
    {
        return _sent.Where(email => email.RecipientEmail == recipient).ToList();
    }

    // Mã OTP 6 số trong email gần nhất gửi tới địa chỉ này
    public string LatestOtp(string recipient)
    {
        var email = To(recipient).LastOrDefault()
            ?? throw new InvalidOperationException($"No email was sent to {recipient}.");

        return Regex.Match(email.TextContent, @"\b\d{6}\b").Value;
    }
}

[CollectionDefinition(Name)]
public sealed class AuthApiCollection : ICollectionFixture<AuthApiFactory>
{
    public const string Name = "auth-api";
}
