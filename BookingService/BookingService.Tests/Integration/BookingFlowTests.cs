using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Services.Interfaces;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Luồng đặt vé + thanh toán (SRS §8.1) với PostgreSQL thật, MovieService / PayOS giả
[Collection(BookingApiCollection.Name)]
public class BookingFlowTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _customerA;
    private readonly HttpClient _customerB;

    public BookingFlowTests(BookingApiFactory factory)
    {
        _factory = factory;
        _customerA = factory.ClientFor(TestUsers.CustomerAToken);
        _customerB = factory.ClientFor(TestUsers.CustomerBToken);
    }

    [Fact]
    public async Task CreateBooking_TakesShowTimeAndTitleFromServer_AndEmailFromToken()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2).Date.AddHours(19));

        var response = await _customerA.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            movieTitle = "Tên phim app tự gửi",
            showTime = "2030-01-01T00:00:00",
            seats = new[] { new { seatId = NewSeat() } }
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var booking = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.Equal("PENDING", booking.GetProperty("status").GetString());
        Assert.Equal(TestUsers.CustomerA.Id, booking.GetProperty("userId").GetInt64());
        Assert.Equal(TestUsers.CustomerA.Email, booking.GetProperty("customerEmail").GetString());
        Assert.Equal(FakeShowtimeClient.MovieTitle, booking.GetProperty("movieTitle").GetString());
        Assert.Equal(showtime.StartTime, booking.GetProperty("showTime").GetDateTime());

        var created = await _factory.OutboxEventsAsync<BookingDbContext>(
            EventTypes.BookingCreated, booking.GetProperty("id").GetInt64());
        Assert.Single(created);
    }

    [Fact]
    public async Task SeatHeldByAnotherBooking_Returns409()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seat = NewSeat();

        await CreateBookingAsync(_customerA, showtime.Id, seat);

        var response = await _customerB.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = seat } }
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task SignedWebhook_ConfirmsBooking_AndStoresPayer()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateBookingAsync(_customerA, showtime.Id, NewSeat(), NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();

        Assert.Equal(HttpStatusCode.OK, (await CheckoutAsync(_customerA, id, amount)).StatusCode);

        // Link PayOS hết hạn đúng lúc hết thời gian giữ ghế (PostgreSQL lưu tới micro giây)
        var linkExpiresAt = _factory.PayOs.LinkExpiresAt[id]!.Value;
        Assert.True(Math.Abs((booking.GetProperty("expiresAt").GetDateTime() - linkExpiresAt).TotalMilliseconds) < 1);

        var webhook = await SendWebhookAsync(_factory.CreateClient(), id, amount);
        Assert.Equal(HttpStatusCode.OK, webhook.StatusCode);

        var confirmed = await _customerA.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}");
        Assert.Equal("CONFIRMED", confirmed.GetProperty("status").GetString());

        var payment = await _factory.QueryAsync<PaymentDbContext, Models.Payment>(db =>
            db.Payments.SingleAsync(p => p.BookingId == id));
        Assert.Equal("SUCCESS", payment.Status);
        Assert.Equal("0011223344", payment.PayerAccountNumber);

        // PayOS gửi lại webhook: không xác nhận / phát event lần hai
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), id, amount)).StatusCode);
        Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingConfirmed, id));
    }

    [Fact]
    public async Task Webhook_WithWrongSignature_Returns400_AndChangesNothing()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateBookingAsync(_customerA, showtime.Id, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();
        await CheckoutAsync(_customerA, id, amount);

        var response = await SendWebhookAsync(_factory.CreateClient(), id, amount, checksumKey: "forged-key");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal("PENDING", await PaymentStatusAsync(id));
    }

    [Fact]
    public async Task ExpiredBooking_ReleasesSeat_AndLatePaymentForTakenSeat_RequestsRefund()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seat = NewSeat();
        var booking = await CreateBookingAsync(_customerA, showtime.Id, seat);
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();
        await CheckoutAsync(_customerA, id, amount);

        await ExpireHoldAsync(id);
        await _factory.ExecuteAsync<IBookingService>(service => service.ExpireOverdueBookingsAsync(100));

        Assert.Equal("EXPIRED", await BookingStatusAsync(id));
        Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingExpired, id));

        // Ghế đã được nhả: khách khác đặt được
        await CreateBookingAsync(_customerB, showtime.Id, seat);

        // Khách A trả tiền muộn: không giữ được ghế -> tự tạo yêu cầu hoàn tiền
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), id, amount)).StatusCode);

        Assert.Equal("EXPIRED", await BookingStatusAsync(id));
        Assert.Equal("REFUND_PENDING", await PaymentStatusAsync(id));
        Assert.Equal(1, await _factory.QueryAsync<PaymentDbContext, int>(db =>
            db.Refunds.CountAsync(r => r.BookingId == id && r.Status == "PENDING")));
    }

    [Fact]
    public async Task CustomerCancelsOnPayOsPage_VerifyReleasesSeatImmediately()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var seat = NewSeat();
        var booking = await CreateBookingAsync(_customerA, showtime.Id, seat);
        var id = booking.GetProperty("id").GetInt64();
        await CheckoutAsync(_customerA, id, booking.GetProperty("totalAmount").GetDecimal());

        _factory.PayOs.Statuses[id] = "CANCELLED";
        var verify = await _customerA.PostAsync($"/api/v1/payments/payos/{id}/verify", null);

        Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
        Assert.Equal("FAILED", await PaymentStatusAsync(id));
        Assert.Equal("CANCELLED", await BookingStatusAsync(id));
        await CreateBookingAsync(_customerB, showtime.Id, seat);
    }

    [Fact]
    public async Task MovieServiceUnavailable_Returns503()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        _factory.Showtimes.Unavailable = true;

        try
        {
            var response = await _customerA.PostAsJsonAsync("/api/v1/bookings", new
            {
                showtimeId = showtime.Id,
                seats = new[] { new { seatId = NewSeat() } }
            });

            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        }
        finally
        {
            _factory.Showtimes.Unavailable = false;
        }
    }

    [Fact]
    public async Task PayOsUnavailable_CheckoutReturns503_AndBookingStaysPayable()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var booking = await CreateBookingAsync(_customerA, showtime.Id, NewSeat());
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();

        _factory.PayOs.Unavailable = true;

        try
        {
            Assert.Equal(HttpStatusCode.ServiceUnavailable, (await CheckoutAsync(_customerA, id, amount)).StatusCode);
        }
        finally
        {
            _factory.PayOs.Unavailable = false;
        }

        // Không tạo payment dở dang: PayOS hoạt động lại thì thanh toán tiếp được
        Assert.Equal(HttpStatusCode.OK, (await CheckoutAsync(_customerA, id, amount)).StatusCode);
    }

    private Task<string> BookingStatusAsync(long id)
    {
        return _factory.QueryAsync<BookingDbContext, string>(db =>
            db.Bookings.Where(b => b.Id == id).Select(b => b.Status).SingleAsync());
    }

    private Task<string> PaymentStatusAsync(long bookingId)
    {
        return _factory.QueryAsync<PaymentDbContext, string>(db =>
            db.Payments.Where(p => p.BookingId == bookingId).Select(p => p.Status).SingleAsync());
    }

    private Task ExpireHoldAsync(long bookingId)
    {
        var past = DateTime.Now.AddMinutes(-1);

        return _factory.QueryAsync<BookingDbContext, int>(async db =>
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE bookings SET expires_at = {past} WHERE id = {bookingId}") +
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE seat_reservations SET held_until = {past} WHERE booking_id = {bookingId}"));
    }
}
