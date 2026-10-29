using BookingService.Configuration;
using BookingService.Services.Interfaces;
using Microsoft.Extensions.Options;

namespace BookingService.Workers
{
    // Chạy nền: nhắc khách trước giờ chiếu (email + lịch sử thông báo trong app), mỗi vé một lần
    public sealed class ShowtimeReminderWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ShowtimeReminderOptions _options;
        private readonly ILogger<ShowtimeReminderWorker> _logger;

        public ShowtimeReminderWorker(
            IServiceScopeFactory scopeFactory,
            IOptions<ShowtimeReminderOptions> options,
            ILogger<ShowtimeReminderWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _options = options.Value;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (!_options.Enabled)
            {
                _logger.LogInformation("Showtime reminder job is disabled.");
                return;
            }

            using var timer = new PeriodicTimer(TimeSpan.FromSeconds(Math.Max(10, _options.IntervalSeconds)));

            try
            {
                do
                {
                    await RemindOnceAsync();
                }
                while (await timer.WaitForNextTickAsync(stoppingToken));
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // Service đang tắt
            }
        }

        private async Task RemindOnceAsync()
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var bookingService = scope.ServiceProvider.GetRequiredService<IBookingService>();
                var reminded = await bookingService.SendShowtimeRemindersAsync(
                    TimeSpan.FromMinutes(Math.Max(1, _options.BeforeMinutes)),
                    Math.Max(1, _options.BatchSize));

                if (reminded > 0)
                {
                    _logger.LogInformation("Sent {Count} showtime reminder(s).", reminded);
                }
            }
            // Database tạm lỗi: ghi log rồi thử lại ở lượt sau
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Showtime reminder job failed, will retry on the next run.");
            }
        }
    }
}
