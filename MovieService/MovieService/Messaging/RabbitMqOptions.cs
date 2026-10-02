namespace MovieService.Messaging
{
    // appsettings: "RabbitMq". Chạy bằng Visual Studio: bật RabbitMQ bằng "docker compose up -d rabbitmq"
    public sealed class RabbitMqOptions
    {
        // false: không kết nối RabbitMQ, event vẫn được ghi vào outbox và sẽ gửi khi bật lại
        public bool Enabled { get; set; } = true;

        public string HostName { get; set; } = "localhost";

        public int Port { get; set; } = 5672;

        public string UserName { get; set; } = "cinema";

        public string Password { get; set; } = "cinema";

        public string VirtualHost { get; set; } = "/";

        // Topic exchange chung của hệ thống, routing key = loại event (vd: booking.confirmed)
        public string Exchange { get; set; } = "cinema.events";

        public string ClientName { get; set; } = "movie-service";

        public int OutboxPollIntervalMs { get; set; } = 1000;

        public int OutboxBatchSize { get; set; } = 50;
    }
}
