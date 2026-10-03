using System.Net;
using BookingService.Tests.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Giám sát (SRS §11): Prometheus đọc /metrics không cần token; metric nghiệp vụ đếm theo trạng thái
[Collection(BookingApiCollection.Name)]
public class ObservabilityTests
{
    private readonly BookingApiFactory _factory;

    public ObservabilityTests(BookingApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Metrics_ArePublicForPrometheus_AndCountBookings()
    {
        var customer = _factory.ClientFor(TestUsers.CustomerAToken);
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        await CreateBookingAsync(customer, showtime.Id, NewSeat());

        var response = await _factory.CreateClient().GetAsync("/metrics");
        var text = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("http_server_request_duration_seconds", text);
        Assert.Matches(@"cinema_bookings_total\{[^}]*status=""created""[^}]*\} [1-9]", text);
        // Series tạo sẵn bằng 0 để Prometheus đếm được cả lần đầu
        Assert.Matches(@"cinema_refunds_total\{[^}]*status=""completed""[^}]*\} \d", text);
    }

    [Fact]
    public async Task Metrics_OnlyServedOnConfiguredInternalPort()
    {
        // Docker: gateway đặt MetricsPort = 9464; request tới cổng khác (cổng mở ra LAN) phải nhận 404
        await using var factory = _factory.WithWebHostBuilder(builder =>
            builder.UseSetting("Observability:MetricsPort", "9464"));

        var response = await factory.CreateClient().GetAsync("/metrics");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
