using System.Text;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Exceptions;

namespace MovieService.Messaging
{
    // Đọc outbox_messages chưa gửi của một database và publish lên RabbitMQ (publisher confirm:
    // chỉ đánh dấu đã gửi khi broker xác nhận đã nhận). RabbitMQ dừng thì event nằm lại trong outbox,
    // worker thử lại tới khi gửi được nên không mất event.
    public sealed class OutboxPublisherWorker<TContext> : BackgroundService where TContext : DbContext
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly RabbitMqConnection _rabbitMq;
        private readonly ILogger<OutboxPublisherWorker<TContext>> _logger;
        private IChannel? _channel;

        public OutboxPublisherWorker(
            IServiceScopeFactory scopeFactory,
            RabbitMqConnection rabbitMq,
            ILogger<OutboxPublisherWorker<TContext>> logger)
        {
            _scopeFactory = scopeFactory;
            _rabbitMq = rabbitMq;
            _logger = logger;
        }

        private RabbitMqOptions Options => _rabbitMq.Options;

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var failures = 0;

            while (!stoppingToken.IsCancellationRequested)
            {
                var published = 0;

                try
                {
                    published = await PublishBatchAsync(stoppingToken);

                    if (failures > 0)
                    {
                        _logger.LogInformation(
                            "Outbox of {Database} is publishing to RabbitMQ again.",
                            typeof(TContext).Name);
                    }

                    failures = 0;
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (System.Exception ex)
                {
                    failures++;

                    // Ghi log lần lỗi đầu và mỗi 30 lần sau đó, tránh ngập log khi RabbitMQ dừng lâu
                    if (failures == 1 || failures % 30 == 0)
                    {
                        _logger.LogWarning(
                            ex,
                            "Could not publish outbox events of {Database} (attempt {Attempt}), will retry.",
                            typeof(TContext).Name,
                            failures);
                    }

                    await CloseChannelAsync();
                }

                // Còn event chưa gửi thì gửi tiếp ngay, không thì chờ lượt quét sau
                if (published >= Options.OutboxBatchSize)
                {
                    continue;
                }

                var delay = failures == 0
                    ? TimeSpan.FromMilliseconds(Options.OutboxPollIntervalMs)
                    : TimeSpan.FromSeconds(Math.Min(30, failures * 2));

                try
                {
                    await Task.Delay(delay, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }

            await CloseChannelAsync();
        }

        private async Task<int> PublishBatchAsync(CancellationToken cancellationToken)
        {
            // Kết nối RabbitMQ trước khi khoá các dòng outbox: RabbitMQ chưa sẵn sàng thì không giữ khoá trong DB
            var channel = await GetChannelAsync(cancellationToken);

            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<TContext>();

            await using var transaction =
                await context.Database.BeginTransactionAsync(cancellationToken);

            // SKIP LOCKED: chạy nhiều instance cùng lúc cũng không gửi trùng một event
            var messages = await context.Set<OutboxMessage>()
                .FromSqlInterpolated($@"
                    SELECT *
                    FROM outbox_messages
                    WHERE published_at IS NULL
                    ORDER BY id
                    LIMIT {Options.OutboxBatchSize}
                    FOR UPDATE SKIP LOCKED")
                .ToListAsync(cancellationToken);

            if (messages.Count == 0)
            {
                await transaction.CommitAsync(cancellationToken);
                return 0;
            }

            try
            {
                foreach (var message in messages)
                {
                    message.Attempts++;

                    // Span con của request đã tạo event (Jaeger: request -> gửi RabbitMQ -> consumer xử lý)
                    using var activity = OutboxTracing.StartPublish(message);

                    var properties = new BasicProperties
                    {
                        MessageId = message.EventId,
                        Type = message.EventType,
                        ContentType = "application/json",
                        DeliveryMode = DeliveryModes.Persistent,
                        Timestamp = new AmqpTimestamp(
                            new DateTimeOffset(message.CreatedAt).ToUnixTimeSeconds())
                    };

                    try
                    {
                        // mandatory: RabbitMQ trả message về nếu chưa có queue nào nhận loại event này
                        await channel.BasicPublishAsync(
                            Options.Exchange,
                            message.EventType,
                            mandatory: true,
                            properties,
                            Encoding.UTF8.GetBytes(message.Payload),
                            cancellationToken);
                    }
                    // Service nhận event chưa khởi động lần nào nên chưa tạo queue: giữ trong outbox, gửi lại sau
                    catch (PublishException ex) when (ex.IsReturn)
                    {
                        message.LastError = $"No queue is bound to '{message.EventType}' yet, will retry.";
                        continue;
                    }

                    message.PublishedAt = DateTime.Now;
                    message.LastError = null;
                }
            }
            catch (System.Exception ex)
            {
                var failed = messages.FirstOrDefault(message => message.PublishedAt == null);

                if (failed != null)
                {
                    failed.LastError = ex.Message.Length <= 1000 ? ex.Message : ex.Message[..1000];
                }

                // Lưu các event đã gửi được để không gửi lại, event lỗi giữ nguyên chờ lần sau
                await context.SaveChangesAsync(CancellationToken.None);
                await transaction.CommitAsync(CancellationToken.None);
                throw;
            }

            await context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return messages.Count(message => message.PublishedAt != null);
        }

        private async Task<IChannel> GetChannelAsync(CancellationToken cancellationToken)
        {
            if (_channel is { IsOpen: true })
            {
                return _channel;
            }

            await CloseChannelAsync();

            var connection = await _rabbitMq.GetConnectionAsync(cancellationToken);

            _channel = await connection.CreateChannelAsync(
                new CreateChannelOptions(
                    publisherConfirmationsEnabled: true,
                    publisherConfirmationTrackingEnabled: true),
                cancellationToken);

            return _channel;
        }

        private async Task CloseChannelAsync()
        {
            if (_channel == null)
            {
                return;
            }

            try
            {
                await _channel.DisposeAsync();
            }
            catch
            {
                // Channel đã hỏng sẵn
            }

            _channel = null;
        }
    }
}
