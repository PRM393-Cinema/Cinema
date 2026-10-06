using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace MovieService.Messaging
{
    // Một kết nối RabbitMQ dùng chung cho cả service. Mất kết nối thì lần gọi sau tự kết nối lại
    // (publisher / consumer tự tạo lại channel), nên không bật auto-recovery của thư viện.
    public sealed class RabbitMqConnection : IAsyncDisposable
    {
        private readonly RabbitMqOptions _options;
        private readonly SemaphoreSlim _lock = new(1, 1);
        private IConnection? _connection;

        public RabbitMqConnection(IOptions<RabbitMqOptions> options)
        {
            _options = options.Value;
        }

        public RabbitMqOptions Options => _options;

        // Message xử lý lỗi nhiều lần được chuyển sang exchange này, vào queue <tên queue>.dlq
        public string DeadLetterExchange => _options.Exchange + ".dlx";

        public bool IsConnected => _connection is { IsOpen: true };

        public async Task<IConnection> GetConnectionAsync(CancellationToken cancellationToken)
        {
            if (_connection is { IsOpen: true } open)
            {
                return open;
            }

            await _lock.WaitAsync(cancellationToken);

            try
            {
                if (_connection is { IsOpen: true } current)
                {
                    return current;
                }

                await CloseAsync();

                var factory = new ConnectionFactory
                {
                    HostName = _options.HostName,
                    Port = _options.Port,
                    UserName = _options.UserName,
                    Password = _options.Password,
                    VirtualHost = _options.VirtualHost,
                    ClientProvidedName = _options.ClientName,
                    AutomaticRecoveryEnabled = false,
                    RequestedHeartbeat = TimeSpan.FromSeconds(30)
                };

                var connection = await factory.CreateConnectionAsync(cancellationToken);

                await using (var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken))
                {
                    await channel.ExchangeDeclareAsync(
                        _options.Exchange,
                        ExchangeType.Topic,
                        durable: true,
                        autoDelete: false,
                        cancellationToken: cancellationToken);

                    await channel.ExchangeDeclareAsync(
                        DeadLetterExchange,
                        ExchangeType.Direct,
                        durable: true,
                        autoDelete: false,
                        cancellationToken: cancellationToken);
                }

                _connection = connection;
                return connection;
            }
            finally
            {
                _lock.Release();
            }
        }

        public async ValueTask DisposeAsync()
        {
            await CloseAsync();
            _lock.Dispose();
        }

        private async Task CloseAsync()
        {
            if (_connection == null)
            {
                return;
            }

            try
            {
                await _connection.DisposeAsync();
            }
            catch
            {
                // Kết nối đã hỏng sẵn
            }

            _connection = null;
        }
    }
}
