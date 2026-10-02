using System.Text.Json;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace BookingService.Messaging
{
    public interface IIntegrationEventHandler
    {
        // Phải idempotent: RabbitMQ có thể giao lại cùng một message (SRS §13.1)
        Task HandleAsync(IntegrationEvent integrationEvent, CancellationToken cancellationToken);
    }

    // Nhận message từ một queue (durable) gắn với các routing key, gọi THandler cho từng message.
    // Lỗi thì thử lại tối đa 3 lần, vẫn lỗi thì chuyển sang queue <tên queue>.dlq để xem xét sau.
    public sealed class EventConsumerWorker<THandler> : BackgroundService
        where THandler : IIntegrationEventHandler
    {
        private const int MaxAttempts = 3;

        private readonly IServiceScopeFactory _scopeFactory;
        private readonly RabbitMqConnection _rabbitMq;
        private readonly ILogger<EventConsumerWorker<THandler>> _logger;
        private readonly string _queue;
        private readonly string[] _routingKeys;

        public EventConsumerWorker(
            IServiceScopeFactory scopeFactory,
            RabbitMqConnection rabbitMq,
            ILogger<EventConsumerWorker<THandler>> logger,
            string queue,
            string[] routingKeys)
        {
            _scopeFactory = scopeFactory;
            _rabbitMq = rabbitMq;
            _logger = logger;
            _queue = queue;
            _routingKeys = routingKeys;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var failures = 0;

            while (!stoppingToken.IsCancellationRequested)
            {
                IChannel? channel = null;

                try
                {
                    channel = await StartConsumingAsync(stoppingToken);

                    if (failures > 0)
                    {
                        _logger.LogInformation("Consuming queue {Queue} again.", _queue);
                    }

                    failures = 0;

                    // Giữ consumer chạy tới khi channel bị đóng (mất kết nối) hoặc service tắt
                    var closed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
                    channel.ChannelShutdownAsync += (_, _) =>
                    {
                        closed.TrySetResult();
                        return Task.CompletedTask;
                    };

                    if (channel.IsOpen)
                    {
                        await closed.Task.WaitAsync(stoppingToken);
                    }

                    _logger.LogWarning("Lost connection while consuming queue {Queue}, reconnecting.", _queue);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    failures++;

                    if (failures == 1 || failures % 30 == 0)
                    {
                        _logger.LogWarning(
                            ex,
                            "Could not consume queue {Queue} (attempt {Attempt}), will retry.",
                            _queue,
                            failures);
                    }
                }
                finally
                {
                    if (channel != null)
                    {
                        try
                        {
                            await channel.DisposeAsync();
                        }
                        catch
                        {
                            // Channel đã hỏng sẵn
                        }
                    }
                }

                try
                {
                    await Task.Delay(TimeSpan.FromSeconds(Math.Min(30, Math.Max(1, failures * 2))), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private async Task<IChannel> StartConsumingAsync(CancellationToken cancellationToken)
        {
            var connection = await _rabbitMq.GetConnectionAsync(cancellationToken);
            var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);

            await channel.BasicQosAsync(0, 10, false, cancellationToken);

            var deadLetterQueue = _queue + ".dlq";

            await channel.QueueDeclareAsync(
                deadLetterQueue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: cancellationToken);

            await channel.QueueBindAsync(
                deadLetterQueue,
                _rabbitMq.DeadLetterExchange,
                _queue,
                cancellationToken: cancellationToken);

            await channel.QueueDeclareAsync(
                _queue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: new Dictionary<string, object?>
                {
                    ["x-dead-letter-exchange"] = _rabbitMq.DeadLetterExchange,
                    ["x-dead-letter-routing-key"] = _queue
                },
                cancellationToken: cancellationToken);

            foreach (var routingKey in _routingKeys)
            {
                await channel.QueueBindAsync(
                    _queue,
                    _rabbitMq.Options.Exchange,
                    routingKey,
                    cancellationToken: cancellationToken);
            }

            var consumer = new AsyncEventingBasicConsumer(channel);
            consumer.ReceivedAsync += (_, delivery) => HandleDeliveryAsync(channel, delivery, cancellationToken);

            await channel.BasicConsumeAsync(_queue, autoAck: false, consumer, cancellationToken);

            _logger.LogInformation(
                "Consuming queue {Queue} ({RoutingKeys}).",
                _queue,
                string.Join(", ", _routingKeys));

            return channel;
        }

        private async Task HandleDeliveryAsync(
            IChannel channel,
            BasicDeliverEventArgs delivery,
            CancellationToken cancellationToken)
        {
            IntegrationEvent? integrationEvent = null;

            try
            {
                integrationEvent = JsonSerializer.Deserialize<IntegrationEvent>(
                    delivery.Body.Span,
                    MessagingJson.Options);
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Message on {Queue} is not valid JSON, moved to dead-letter queue.", _queue);
            }

            if (integrationEvent == null || string.IsNullOrWhiteSpace(integrationEvent.EventId))
            {
                await channel.BasicNackAsync(delivery.DeliveryTag, false, requeue: false, cancellationToken);
                return;
            }

            for (var attempt = 1; ; attempt++)
            {
                try
                {
                    using var scope = _scopeFactory.CreateScope();
                    var handler = scope.ServiceProvider.GetRequiredService<THandler>();

                    await handler.HandleAsync(integrationEvent, cancellationToken);
                    await channel.BasicAckAsync(delivery.DeliveryTag, false, cancellationToken);
                    return;
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    // Service đang tắt: message chưa ack sẽ được RabbitMQ giao lại sau
                    return;
                }
                catch (Exception ex) when (attempt < MaxAttempts)
                {
                    _logger.LogWarning(
                        ex,
                        "Handling {EventType} {EventId} failed (attempt {Attempt}), retrying.",
                        integrationEvent.EventType,
                        integrationEvent.EventId,
                        attempt);

                    await Task.Delay(TimeSpan.FromSeconds(attempt), cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        ex,
                        "Handling {EventType} {EventId} failed {Attempts} times, moved to {Queue}.dlq.",
                        integrationEvent.EventType,
                        integrationEvent.EventId,
                        MaxAttempts,
                        _queue);

                    await channel.BasicNackAsync(delivery.DeliveryTag, false, requeue: false, cancellationToken);
                    return;
                }
            }
        }
    }
}
