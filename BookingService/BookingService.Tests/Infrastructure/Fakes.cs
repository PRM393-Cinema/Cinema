using System.Collections.Concurrent;
using BookingService.Clients;
using BookingService.Clients.Interfaces;
using BookingService.DTOs;
using BookingService.Exceptions;

namespace BookingService.Tests.Infrastructure;

// MovieService giả: suất chiếu do test tạo, ghế nào cũng hợp lệ với nhãn "S{id}"
public sealed class FakeShowtimeClient : IShowtimeClient
{
    private readonly ConcurrentDictionary<long, ShowtimeInfo> _showtimes = new();
    private long _nextId = 1000;

    public const string MovieTitle = "Phim Kiểm Thử";

    public decimal SeatPrice { get; set; } = 90_000;

    // Giả lập MovieService chết / circuit breaker mở
    public bool Unavailable { get; set; }

    public ShowtimeInfo AddShowtime(DateTime startTime, string status = "OPEN")
    {
        var showtime = new ShowtimeInfo
        {
            Id = Interlocked.Increment(ref _nextId),
            MovieId = 7,
            StartTime = startTime,
            EndTime = startTime.AddHours(2),
            Status = status
        };

        _showtimes[showtime.Id] = showtime;
        return showtime;
    }

    public Task<List<ShowtimeSeatInfo>> GetSeatsAsync(long showtimeId, List<long> seatIds)
    {
        var showtime = Get(showtimeId);

        if (showtime.Status != "OPEN")
        {
            throw new BusinessException($"Showtime with ID {showtimeId} is not open for booking.");
        }

        return Task.FromResult(seatIds
            .Distinct()
            .Select(id => new ShowtimeSeatInfo { SeatId = id, SeatLabel = $"S{id}", Price = SeatPrice })
            .ToList());
    }

    public Task<ShowtimeInfo> GetShowtimeAsync(long showtimeId)
    {
        return Task.FromResult(Get(showtimeId));
    }

    public Task<string?> GetMovieTitleAsync(long movieId)
    {
        return Task.FromResult<string?>(MovieTitle);
    }

    private ShowtimeInfo Get(long showtimeId)
    {
        if (Unavailable)
        {
            throw new ServiceUnavailableException(
                "Showtime service is temporarily unavailable. Please try again later.");
        }

        return _showtimes.TryGetValue(showtimeId, out var showtime)
            ? showtime
            : throw new NotFoundException($"Showtime with ID {showtimeId} was not found.");
    }
}

// PayOS giả: ghi lại link đã tạo / đã huỷ, trạng thái đơn do test đặt
public sealed class FakePayOsClient : IPayOsClient
{
    public ConcurrentDictionary<long, string> Statuses { get; } = new();

    public ConcurrentDictionary<long, DateTime?> LinkExpiresAt { get; } = new();

    public ConcurrentBag<long> CancelledLinks { get; } = new();

    public bool Unavailable { get; set; }

    public Task<PayOsPaymentLink> CreatePaymentLinkAsync(
        long orderCode,
        decimal amount,
        string description,
        string returnUrl,
        string cancelUrl,
        DateTime? expiresAt = null,
        CancellationToken cancellationToken = default)
    {
        ThrowIfUnavailable();

        Statuses[orderCode] = "PENDING";
        LinkExpiresAt[orderCode] = expiresAt;

        return Task.FromResult(new PayOsPaymentLink
        {
            OrderCode = orderCode,
            CheckoutUrl = $"https://pay.example/{orderCode}",
            PaymentLinkId = $"link-{orderCode}"
        });
    }

    public Task<PayOsPaymentStatus> GetPaymentStatusAsync(
        long orderCode,
        CancellationToken cancellationToken = default)
    {
        ThrowIfUnavailable();

        return Task.FromResult(new PayOsPaymentStatus
        {
            OrderCode = orderCode,
            Status = Statuses.GetValueOrDefault(orderCode, "PENDING"),
            CheckoutUrl = $"https://pay.example/{orderCode}"
        });
    }

    public Task CancelPaymentLinkAsync(
        long orderCode,
        string reason,
        CancellationToken cancellationToken = default)
    {
        ThrowIfUnavailable();

        CancelledLinks.Add(orderCode);
        Statuses[orderCode] = "CANCELLED";
        return Task.CompletedTask;
    }

    private void ThrowIfUnavailable()
    {
        if (Unavailable)
        {
            throw new ServiceUnavailableException("PayOS is temporarily unavailable. Please try again later.");
        }
    }
}

// SMTP giả: giữ lại các email đã gửi để test kiểm tra
public sealed class FakeEmailSender : IEmailSender
{
    public ConcurrentQueue<EmailMessage> Sent { get; } = new();

    public Task SendAsync(EmailMessage email, CancellationToken cancellationToken = default)
    {
        Sent.Enqueue(email);
        return Task.CompletedTask;
    }

    public List<EmailMessage> To(string recipient)
    {
        return Sent.Where(email => email.RecipientEmail == recipient).ToList();
    }
}
