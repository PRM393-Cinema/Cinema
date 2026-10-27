using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Services.Interfaces;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Điểm thành viên: cộng điểm theo hạng khi vé đã thanh toán, dùng điểm tối đa 50% đơn, trả điểm khi vé
// không thành, thu hồi điểm khi vé đã trả bị huỷ. Mỗi test dùng một khách riêng để số điểm không lẫn nhau.
[Collection(BookingApiCollection.Name)]
public class LoyaltyTests
{
    private static long _nextMember = 9000;

    private readonly BookingApiFactory _factory;
    private readonly HttpClient _admin;
    private readonly HttpClient _staff;

    public LoyaltyTests(BookingApiFactory factory)
    {
        _factory = factory;
        _admin = factory.ClientFor(TestUsers.AdminToken);
        _staff = factory.ClientFor(TestUsers.StaffToken);
    }

    [Fact]
    public async Task PaidTicketsEarnPointsByTier_AndTheTierRisesWithSpend()
    {
        var (memberId, member) = NewMember();

        var card = await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(0, card.GetProperty("points").GetInt32());
        Assert.Equal("MEMBER", card.GetProperty("tier").GetString());
        Assert.Equal(5m, card.GetProperty("earnRatePercent").GetDecimal());
        Assert.Equal("VIP", card.GetProperty("nextTier").GetString());
        Assert.Equal(2_000_000m, card.GetProperty("nextTierSpend").GetDecimal());

        // Chưa thanh toán thì chưa có điểm
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));
        var pending = await CreateBookingAsync(member, showtime.Id, NewSeat());
        Assert.Equal(0, (await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me")).GetProperty("points").GetInt32());

        // 1 vé 90.000 ở hạng MEMBER (5%): 4.500đ = 4 điểm
        var id = await PayAsync(member, pending);
        var paid = await member.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}");
        Assert.Equal(4, paid.GetProperty("pointsEarned").GetInt32());

        // 23 vé 2.070.000đ: vẫn tính 5% (hạng trước khi cộng đơn) = 103 điểm, rồi lên VIP
        await PayAsync(member, await CreateBookingAsync(member, showtime.Id,
            Enumerable.Range(0, 23).Select(_ => NewSeat()).ToArray()));
        card = await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(107, card.GetProperty("points").GetInt32());
        Assert.Equal("VIP", card.GetProperty("tier").GetString());
        Assert.Equal(2_160_000m, card.GetProperty("lifetimeSpend").GetDecimal());
        Assert.Equal(7m, card.GetProperty("earnRatePercent").GetDecimal());

        // Hạng VIP (7%): 6.300đ = 6 điểm
        await PayAsync(member, await CreateBookingAsync(member, showtime.Id, NewSeat()));
        card = await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(113, card.GetProperty("points").GetInt32());
        var history = card.GetProperty("transactions").EnumerateArray().ToList();
        Assert.Equal(3, history.Count);
        Assert.All(history, line => Assert.Equal("EARN", line.GetProperty("type").GetString()));
        Assert.Equal(6, history[0].GetProperty("points").GetInt32());

        // Quầy xem được thẻ của khách; khách không xem được thẻ người khác
        var seen = await _staff.GetFromJsonAsync<JsonElement>($"/api/v1/loyalty/users/{memberId}");
        Assert.Equal(113, seen.GetProperty("points").GetInt32());
        Assert.Equal(HttpStatusCode.Forbidden,
            (await member.GetAsync($"/api/v1/loyalty/users/{TestUsers.CustomerA.Id}")).StatusCode);

        var accounts = await _admin.GetFromJsonAsync<JsonElement>($"/api/v1/loyalty/accounts?userIds={memberId},987654");
        Assert.Equal(113, accounts[0].GetProperty("points").GetInt32());
        Assert.Equal(0, accounts[1].GetProperty("points").GetInt32());
        Assert.Equal("MEMBER", accounts[1].GetProperty("tier").GetString());
    }

    [Fact]
    public async Task PointsPayUpToHalf_ComeBackWhenUnpaid_AndAreTakenBackOnCancel()
    {
        var (memberId, member) = NewMember();

        // Chỉ Admin chỉnh điểm, phải có lý do, không để điểm âm
        Assert.Equal(HttpStatusCode.Forbidden, (await _staff.PostAsJsonAsync(
            $"/api/v1/loyalty/users/{memberId}/adjust", new { points = 100, note = "x" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PostAsJsonAsync(
            $"/api/v1/loyalty/users/{memberId}/adjust", new { points = 100 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PostAsJsonAsync(
            $"/api/v1/loyalty/users/{memberId}/adjust", new { points = -1, note = "Trừ thử" })).StatusCode);
        var adjusted = await _admin.PostAsJsonAsync(
            $"/api/v1/loyalty/users/{memberId}/adjust", new { points = 100, note = "Quà chào mừng" });
        Assert.Equal(HttpStatusCode.OK, adjusted.StatusCode);
        Assert.Equal(100, (await adjusted.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("points").GetInt32());

        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));

        // 2 vé 180.000đ: dùng tối đa 90 điểm (50%)
        var tooMany = await BookAsync(member, showtime.Id, 2, usePoints: 91);
        Assert.Equal(HttpStatusCode.BadRequest, tooMany.StatusCode);
        Assert.Contains("at most 90 points", await tooMany.Content.ReadAsStringAsync());

        var held = await ReadAsync(await BookAsync(member, showtime.Id, 2, usePoints: 50));
        Assert.Equal(50, held.GetProperty("pointsUsed").GetInt32());
        Assert.Equal(50_000m, held.GetProperty("pointsDiscount").GetDecimal());
        Assert.Equal(130_000m, held.GetProperty("totalAmount").GetDecimal());
        Assert.Equal(50, await PointsAsync(member));

        var notEnough = await BookAsync(member, showtime.Id, 2, usePoints: 60);
        Assert.Equal(HttpStatusCode.BadRequest, notEnough.StatusCode);
        Assert.Contains("only have 50 points", await notEnough.Content.ReadAsStringAsync());

        // Giữ chỗ hết hạn: trả lại điểm đã dùng
        await ExpireHoldAsync(held.GetProperty("id").GetInt64());
        await _factory.ExecuteAsync<IBookingService>(service => service.ExpireOverdueBookingsAsync(100));
        Assert.Equal(100, await PointsAsync(member));

        // 1 vé 90.000đ dùng 40 điểm: trả 50.000đ, được cộng 5% = 2 điểm
        var used = await ReadAsync(await BookAsync(member, showtime.Id, 1, usePoints: 40));
        var id = await PayAsync(member, used);
        Assert.Equal(62, await PointsAsync(member));
        Assert.Equal(2, (await member.GetFromJsonAsync<JsonElement>($"/api/v1/bookings/{id}"))
            .GetProperty("pointsEarned").GetInt32());

        // Quầy huỷ vé đã trả: trả 40 điểm đã dùng, thu hồi 2 điểm đã cộng, tổng chi tiêu về 0
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{id}/cancel", null)).StatusCode);
        var card = await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me");
        Assert.Equal(100, card.GetProperty("points").GetInt32());
        Assert.Equal(0m, card.GetProperty("lifetimeSpend").GetDecimal());
        var types = card.GetProperty("transactions").EnumerateArray()
            .Select(line => line.GetProperty("type").GetString()).ToList();
        Assert.Equal(["REVERSE", "RETURN", "EARN", "REDEEM", "RETURN", "REDEEM", "ADJUST"], types);

        // Vé khách vãng lai (không có tài khoản) không dùng được điểm
        var walkIn = await _staff.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() } },
            usePoints = 10
        });
        Assert.Equal(HttpStatusCode.BadRequest, walkIn.StatusCode);
    }

    [Fact]
    public async Task TheCounterUsesAMembersPoints()
    {
        var (memberId, member) = NewMember();
        await _admin.PostAsJsonAsync($"/api/v1/loyalty/users/{memberId}/adjust", new { points = 30, note = "Thử" });
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddDays(2));

        var response = await _staff.PostAsJsonAsync("/api/v1/bookings", new
        {
            userId = memberId,
            customerEmail = $"member{memberId}@test.local",
            showtimeId = showtime.Id,
            seats = new[] { new { seatId = NewSeat() } },
            usePoints = 30
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var booking = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(60_000m, booking.GetProperty("totalAmount").GetDecimal());

        // Trả tiền mặt: khách được cộng 5% của 60.000đ = 3 điểm
        var cash = await _staff.PostAsJsonAsync("/api/v1/payments/cash", new
        {
            bookingId = booking.GetProperty("id").GetInt64(),
            amountReceived = 60_000
        });
        Assert.Equal(HttpStatusCode.OK, cash.StatusCode);
        Assert.Equal(3, await PointsAsync(member));
        var spend = await _factory.QueryAsync<BookingDbContext, decimal>(db =>
            db.LoyaltyAccounts.Where(a => a.UserId == memberId).Select(a => a.LifetimeSpend).SingleAsync());
        Assert.Equal(60_000m, spend);
    }

    private (long Id, HttpClient Client) NewMember()
    {
        var id = Interlocked.Increment(ref _nextMember);
        return (id, _factory.ClientFor(TestJwt.Create(id, $"member{id}@test.local", "ROLE_CUSTOMER")));
    }

    private static Task<HttpResponseMessage> BookAsync(HttpClient client, long showtimeId, int seats, int usePoints)
    {
        return client.PostAsJsonAsync("/api/v1/bookings", new
        {
            showtimeId,
            seats = Enumerable.Range(0, seats).Select(_ => new { seatId = NewSeat() }).ToArray(),
            usePoints
        });
    }

    private static async Task<JsonElement> ReadAsync(HttpResponseMessage response)
    {
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private static async Task<int> PointsAsync(HttpClient member)
    {
        return (await member.GetFromJsonAsync<JsonElement>("/api/v1/loyalty/me")).GetProperty("points").GetInt32();
    }

    private async Task<long> PayAsync(HttpClient member, JsonElement booking)
    {
        var id = booking.GetProperty("id").GetInt64();
        var amount = booking.GetProperty("totalAmount").GetDecimal();
        var orderCode = await CheckoutOrderCodeAsync(member, id, amount);
        Assert.Equal(HttpStatusCode.OK, (await SendWebhookAsync(_factory.CreateClient(), orderCode, amount)).StatusCode);
        return id;
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
