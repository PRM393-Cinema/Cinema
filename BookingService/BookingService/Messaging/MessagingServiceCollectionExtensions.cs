using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BookingService.Messaging
{
    public static class MessagingServiceCollectionExtensions
    {
        // Kết nối RabbitMQ + ghi outbox. Worker gửi / nhận message chỉ chạy khi RabbitMq:Enabled = true
        public static IServiceCollection AddRabbitMqMessaging(
            this IServiceCollection services,
            IConfiguration configuration)
        {
            services.Configure<RabbitMqOptions>(configuration.GetSection("RabbitMq"));
            services.AddSingleton<RabbitMqConnection>();
            services.AddScoped(typeof(OutboxWriter<>));

            return services;
        }

        public static IServiceCollection AddOutboxPublisher<TContext>(
            this IServiceCollection services,
            IConfiguration configuration)
            where TContext : DbContext
        {
            if (IsEnabled(configuration))
            {
                services.AddHostedService<OutboxPublisherWorker<TContext>>();
            }

            return services;
        }

        public static IServiceCollection AddEventConsumer<THandler>(
            this IServiceCollection services,
            IConfiguration configuration,
            string queue,
            params string[] routingKeys)
            where THandler : class, IIntegrationEventHandler
        {
            services.AddScoped<THandler>();

            if (IsEnabled(configuration))
            {
                services.AddHostedService(provider => new EventConsumerWorker<THandler>(
                    provider.GetRequiredService<IServiceScopeFactory>(),
                    provider.GetRequiredService<RabbitMqConnection>(),
                    provider.GetRequiredService<ILogger<EventConsumerWorker<THandler>>>(),
                    queue,
                    routingKeys));
            }

            return services;
        }

        private static bool IsEnabled(IConfiguration configuration)
        {
            return configuration.GetSection("RabbitMq").Get<RabbitMqOptions>()?.Enabled ?? true;
        }
    }
}
