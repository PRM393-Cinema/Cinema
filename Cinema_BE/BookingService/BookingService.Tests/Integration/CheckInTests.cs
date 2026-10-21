using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Tests.Infrastructure;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Check-in tại rạp: Staff tra vé theo mã (QR trên vé) rồi check-in. Vé chưa trả tiền, đã check-in,
// đã huỷ hoặc chưa tới giờ check-in thì bị từ chối kèm lý do.
[Collection(BookingApiCollection.Name)]
public class CheckInTests
{
    private readonly BookingApiFactory _factory;
    private readonly HttpClient _customer;
    private readonly HttpClient _staff;

    public CheckInTests(BookingApiFactory factory)
    {
        _factory = factory;
        _customer = factory.ClientFor(TestUsers.CustomerAToken);
        _staff = factory.ClientFor(TestUsers.StaffToken);
    }

    [Fact]
    public async Task StaffFindsPaidBookingByCode_AndChecksItInOnce()
    {
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddHours(1));
        var seat = NewSeat();
        var id = await CreatePaidBookingAsync(_factory, _customer, showtime.Id, seat);
        var code = (await _customer.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}"))
            .GetProperty("bookingCode").GetString()!;

        Assert.Equal(HttpStatusCode.Forbidden, (await _customer.GetAsync($"/api/v1/bookings/code/{code}")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _customer.PostAsync($"/api/v1/bookings/{id}/check-in", null)).StatusCode);

        // Mã gõ tay có thể là chữ thường
        var found = await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/code/{code.ToLowerInvariant()}");
        Assert.Equal(id, found.GetProperty("id").GetInt64());
        Assert.False(IsCheckedIn(found));
        Assert.Equal(HttpStatusCode.NotFound, (await _staff.GetAsync("/api/v1/bookings/code/BK-UNKNOWN")).StatusCode);

        // Sơ đồ ghế đã đặt của suất: ghế thuộc vé này, chưa check-in
        var seatRow = Assert.Single((await SeatBookingsAsync(showtime.Id)).EnumerateArray());
        Assert.Equal(seat, seatRow.GetProperty("seatId").GetInt64());
        Assert.Equal(code, seatRow.GetProperty("bookingCode").GetString());
        Assert.Equal("CONFIRMED", seatRow.GetProperty("status").GetString());
        Assert.False(IsCheckedIn(seatRow));

        var checkIn = await _staff.PostAsync($"/api/v1/bookings/{id}/check-in", null);
        Assert.Equal(HttpStatusCode.OK, checkIn.StatusCode);
        Assert.True(IsCheckedIn(await checkIn.Content.ReadFromJsonAsync<JsonElement>()));

        var again = await _staff.PostAsync($"/api/v1/bookings/{id}/check-in", null);
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode);
        Assert.Contains("already checked in", await again.Content.ReadAsStringAsync());

        Assert.True(IsCheckedIn(Assert.Single((await SeatBookingsAsync(showtime.Id)).EnumerateArray())));
        Assert.True(IsCheckedIn(await _customer.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}")));
    }

    [Fact]
    public async Task UnpaidCancelledOrEarlyBookings_CannotCheckIn()
    {
        var soon = _factory.Showtimes.AddShowtime(DateTime.Now.AddHours(1));
        var pending = (await CreateBookingAsync(_customer, soon.Id, NewSeat())).GetProperty("id").GetInt64();
        await AssertRejectedAsync(pending, "has not been paid");

        // Suất chiếu 2 ngày nữa: chưa tới giờ mở check-in
        var later = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var early = await CreatePaidBookingAsync(_factory, _customer, later.Id, NewSeat());
        await AssertRejectedAsync(early, "opens at");

        var cancelled = await CreatePaidBookingAsync(_factory, _customer, soon.Id, NewSeat());
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{cancelled}/cancel", null)).StatusCode);
        await AssertRejectedAsync(cancelled, "cancelled");
    }

    private async Task AssertRejectedAsync(long bookingId, string reason)
    {
        var response = await _staff.PostAsync($"/api/v1/bookings/{bookingId}/check-in", null);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains(reason, await response.Content.ReadAsStringAsync());
    }

    private Task<JsonElement> SeatBookingsAsync(long showtimeId) =>
        _staff.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/showtime/{showtimeId}/seats");

    private static bool IsCheckedIn(JsonElement booking) =>
        booking.TryGetProperty("checkedInAt", out var value) && value.ValueKind == JsonValueKind.String;
}
