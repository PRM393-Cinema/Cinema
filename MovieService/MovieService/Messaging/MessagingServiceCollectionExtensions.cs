using Microsoft.EntityFrameworkCore;

namespace MovieService.Messaging
{
    public static class MessagingServiceCollectionExtensions
    {
        // Kết nối RabbitMQ + ghi outbox. Worker gửi message chỉ chạy khi RabbitMq:Enabled = true
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
            if (configuration.GetSection("RabbitMq").Get<RabbitMqOptions>()?.Enabled ?? true)
            {
                services.AddHostedService<OutboxPublisherWorker<TContext>>();
            }

            return services;
        }
    }
}
