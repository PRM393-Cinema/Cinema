using BookingService.Configuration;
using BookingService.Services.Interfaces;
using Microsoft.Extensions.Options;

namespace BookingService.Workers
{
    // Chạy nền: booking PENDING quá hạn giữ ghế (10 phút) -> EXPIRED, nhả ghế cho người khác đặt,
    // payment PayOS còn PENDING của booking đó -> FAILED (link PayOS cũng hết hạn cùng lúc).
    public sealed class BookingExpiryWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly BookingExpiryOptions _options;
        private readonly ILogger<BookingExpiryWorker> _logger;

        public BookingExpiryWorker(
            IServiceScopeFactory scopeFactory,
            IOptions<BookingExpiryOptions> options,
            ILogger<BookingExpiryWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _options = options.Value;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (!_options.Enabled)
            {
                _logger.LogInformation("Booking expiry job is disabled.");
                return;
            }

            using var timer = new PeriodicTimer(
                TimeSpan.FromSeconds(Math.Max(5, _options.IntervalSeconds)));

            try
            {
                do
                {
                    await ExpireOnceAsync();
                }
                while (await timer.WaitForNextTickAsync(stoppingToken));
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // Service đang tắt
            }
        }

        private async Task ExpireOnceAsync()
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var bookingService = scope.ServiceProvider.GetRequiredService<IBookingService>();
                var paymentService = scope.ServiceProvider.GetRequiredService<IPaymentService>();

                var expired = await bookingService.ExpireOverdueBookingsAsync(
                    Math.Max(1, _options.BatchSize));

                foreach (var booking in expired.Where(booking => booking.PaymentId.HasValue))
                {
                    await paymentService.MarkUnpaidPaymentFailedAsync(booking.PaymentId!.Value);
                }

                if (expired.Count > 0)
                {
                    _logger.LogInformation(
                        "Expired {Count} unpaid booking(s): {BookingCodes}",
                        expired.Count,
                        string.Join(", ", expired.Select(booking => booking.BookingCode)));
                }
            }
            // Database tạm lỗi: ghi log rồi thử lại ở lượt sau, không làm dừng service
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Booking expiry job failed, will retry on the next run.");
            }
        }
    }
}
