using System.Net.Http.Headers;
using System.Text.Json;
using BookingService.Clients.Interfaces;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Models;
using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Testcontainers.PostgreSql;

namespace BookingService.Tests.Infrastructure;

// BookingService chạy trong bộ nhớ với PostgreSQL thật (container riêng cho mỗi lần chạy test).
// MovieService, PayOS, SMTP được thay bằng bản giả; RabbitMQ tắt (bản RabbitMqApiFactory bật).
public class BookingApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string ChecksumKey = "test-checksum-key";

    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine")
        .Build();

    public FakeShowtimeClient Showtimes { get; } = new();

    public FakePayOsClient PayOs { get; } = new();

    public FakeEmailSender Emails { get; } = new();

    protected IContainer? RabbitMqContainer { get; private set; }

    protected virtual bool UseRabbitMq => false;

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        if (UseRabbitMq)
        {
            RabbitMqContainer = new ContainerBuilder("rabbitmq:4-management-alpine")
                .WithEnvironment("RABBITMQ_DEFAULT_USER", "cinema")
                .WithEnvironment("RABBITMQ_DEFAULT_PASS", "cinema")
                .WithPortBinding(5672, true)
                .WithWaitStrategy(Wait.ForUnixContainer().UntilMessageIsLogged("Server startup complete"))
                .Build();

            await RabbitMqContainer.StartAsync();
        }

        // Tạo bảng từ model EF (giống file SQL của repo Project-Cinema-DB) trước khi service khởi động
        await EnsureCreatedAsync<BookingDbContext>(ConnectionString("cinema_booking_test"), options => new BookingDbContext(options));
        await EnsureCreatedAsync<PaymentDbContext>(ConnectionString("cinema_payment_test"), options => new PaymentDbContext(options));
        await EnsureCreatedAsync<NotificationDbContext>(ConnectionString("cinema_notification_test"), options => new NotificationDbContext(options));
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        await _postgres.DisposeAsync();

        if (RabbitMqContainer != null)
        {
            await RabbitMqContainer.DisposeAsync();
        }
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        // Chỉ in cảnh báo / lỗi để kết quả test dễ đọc
        builder.UseSetting("Logging:LogLevel:Default", "Warning");
        builder.UseSetting("Logging:LogLevel:Microsoft.EntityFrameworkCore", "Warning");
        builder.UseSetting("ConnectionStrings:BookingDb", ConnectionString("cinema_booking_test"));
        builder.UseSetting("ConnectionStrings:PaymentDb", ConnectionString("cinema_payment_test"));
        builder.UseSetting("ConnectionStrings:NotificationDb", ConnectionString("cinema_notification_test"));
        builder.UseSetting("Jwt:SecretKey", TestJwt.SecretKey);
        builder.UseSetting("PayOS:ClientId", "test-client");
        builder.UseSetting("PayOS:ApiKey", "test-api-key");
        builder.UseSetting("PayOS:ChecksumKey", ChecksumKey);
        builder.UseSetting("BookingExpiry:Enabled", "false");
        builder.UseSetting("RabbitMq:Enabled", UseRabbitMq ? "true" : "false");

        if (RabbitMqContainer != null)
        {
            builder.UseSetting("RabbitMq:HostName", RabbitMqContainer.Hostname);
            builder.UseSetting("RabbitMq:Port", RabbitMqContainer.GetMappedPublicPort(5672).ToString());
            builder.UseSetting("RabbitMq:OutboxPollIntervalMs", "200");
        }

        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IShowtimeClient>();
            services.AddSingleton<IShowtimeClient>(Showtimes);
            services.RemoveAll<IPayOsClient>();
            services.AddSingleton<IPayOsClient>(PayOs);
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

    public async Task<T> QueryAsync<TContext, T>(Func<TContext, Task<T>> query)
        where TContext : DbContext
    {
        using var scope = Services.CreateScope();
        return await query(scope.ServiceProvider.GetRequiredService<TContext>());
    }

    public async Task ExecuteAsync<TService>(Func<TService, Task> action)
        where TService : notnull
    {
        using var scope = Services.CreateScope();
        await action(scope.ServiceProvider.GetRequiredService<TService>());
    }

    // Các event trong outbox của một booking (đọc từ database chứa outbox)
    public Task<List<IntegrationEvent>> OutboxEventsAsync<TContext>(string eventType, long bookingId)
        where TContext : DbContext
    {
        return QueryAsync<TContext, List<IntegrationEvent>>(async db =>
        {
            var payloads = await db.Set<OutboxMessage>()
                .Where(message => message.EventType == eventType)
                .OrderBy(message => message.Id)
                .Select(message => message.Payload)
                .ToListAsync();

            return payloads
                .Select(payload => JsonSerializer.Deserialize<IntegrationEvent>(payload, MessagingJson.Options)!)
                .Where(e => e.Data.GetProperty("bookingId").GetInt64() == bookingId)
                .ToList();
        });
    }

    // Chạy handler như consumer RabbitMQ nhận được message
    public Task HandleAsync<THandler>(IntegrationEvent integrationEvent)
        where THandler : IIntegrationEventHandler
    {
        return ExecuteAsync<THandler>(handler => handler.HandleAsync(integrationEvent, CancellationToken.None));
    }

    private string ConnectionString(string database)
    {
        return new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
        {
            Database = database
        }.ConnectionString;
    }

    private static async Task EnsureCreatedAsync<TContext>(
        string connectionString,
        Func<DbContextOptions<TContext>, TContext> create)
        where TContext : DbContext
    {
        var options = new DbContextOptionsBuilder<TContext>()
            .UseNpgsql(connectionString)
            .Options;

        await using var context = create(options);
        await context.Database.EnsureCreatedAsync();
    }
}

// Bản có RabbitMQ thật (container): kiểm tra event được publish / consume qua broker
public sealed class RabbitMqApiFactory : BookingApiFactory
{
    protected override bool UseRabbitMq => true;
}

[CollectionDefinition(Name)]
public sealed class BookingApiCollection : ICollectionFixture<BookingApiFactory>
{
    public const string Name = "booking-api";
}

[CollectionDefinition(Name)]
public sealed class RabbitMqCollection : ICollectionFixture<RabbitMqApiFactory>
{
    public const string Name = "booking-rabbitmq";
}
