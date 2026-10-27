using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Messaging;
using BookingService.Messaging.Handlers;
using BookingService.Services.Interfaces;
using BookingService.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Nhắc giờ chiếu (job chạy nền) và trạng thái đã đọc của thông báo trong app.
// Mỗi test dùng khách riêng để số thông báo chưa đọc không lẫn nhau.
[Collection(BookingApiCollection.Name)]
public class ShowtimeReminderTests
{
    private static long _nextCustomer = 9800;

    private readonly BookingApiFactory _factory;
    private readonly HttpClient _staff;

    public ShowtimeReminderTests(BookingApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(TestUsers.StaffToken);
    }

    [Fact]
    public async Task PaidTicketsAreRemindedOnce_BeforeTheShow()
    {
        var (email, customer) = NewCustomer();
        var soon = await PaidBookingAsync(customer, DateTime.Now.AddHours(1), bookedHoursAgo: 24);
        var later = await PaidBookingAsync(customer, DateTime.Now.AddHours(5), bookedHoursAgo: 24);
        var checkedIn = await PaidBookingAsync(customer, DateTime.Now.AddHours(1), bookedHoursAgo: 24);
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{checkedIn}/check-in", null)).StatusCode);
        // Đặt khi đã gần giờ chiếu: khách vừa nhận email xác nhận, không nhắc nữa
        var justBooked = await PaidBookingAsync(customer, DateTime.Now.AddHours(1), bookedHoursAgo: 0);

        await RemindAsync();
        await RemindAsync();

        var reminder = Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingReminder, soon));
        Assert.Empty(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingReminder, later));
        Assert.Empty(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingReminder, checkedIn));
        Assert.Empty(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingReminder, justBooked));
        Assert.NotNull(await RemindedAtAsync(justBooked));
        Assert.Null(await RemindedAtAsync(later));

        // Email nhắc và thông báo trong app
        await _factory.HandleAsync<NotificationEventHandler>(reminder);
        var mail = Assert.Single(_factory.Emails.To(email), message => message.Subject.StartsWith("Nhắc giờ chiếu"));
        Assert.Contains("Sắp tới giờ chiếu", mail.Content);
        var notifications = await customer.GetFromJsonAsync<JsonElement>($"/api/v1/notifications/user/{UserIdOf(email)}");
        Assert.Contains(notifications.GetProperty("items").EnumerateArray(),
            item => item.GetProperty("type").GetString() == "SHOWTIME_REMINDER" &&
                    item.GetProperty("bookingId").GetInt64() == soon);
    }

    [Fact]
    public async Task NotificationsStayUnreadUntilOpened_AndCanAllBeRead()
    {
        var (email, customer) = NewCustomer();
        var userId = UserIdOf(email);
        foreach (var hours in new[] { 1, 2 })
        {
            var id = await PaidBookingAsync(customer, DateTime.Now.AddHours(hours), bookedHoursAgo: 24);
            await RemindAsync();
            await _factory.HandleAsync<NotificationEventHandler>(
                Assert.Single(await _factory.OutboxEventsAsync<BookingDbContext>(EventTypes.BookingReminder, id)));
        }

        Assert.Equal(2, await UnreadAsync(customer));
        var items = (await customer.GetFromJsonAsync<JsonElement>($"/api/v1/notifications/user/{userId}"))
            .GetProperty("items").EnumerateArray().ToList();
        Assert.All(items, item => Assert.Equal(JsonValueKind.Null, item.GetProperty("readAt").ValueKind));
        var first = items[0].GetProperty("id").GetInt64();

        // Người khác không đánh dấu được; mở lần hai giữ thời điểm đọc đầu tiên
        var (_, stranger) = NewCustomer();
        Assert.Equal(HttpStatusCode.Forbidden, (await stranger.PatchAsync($"/api/v1/notifications/{first}/read", null)).StatusCode);
        var read = await (await customer.PatchAsync($"/api/v1/notifications/{first}/read", null))
            .Content.ReadFromJsonAsync<JsonElement>();
        var readAt = read.GetProperty("readAt").GetDateTime();
        var again = await (await customer.PatchAsync($"/api/v1/notifications/{first}/read", null))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(readAt, again.GetProperty("readAt").GetDateTime());
        Assert.Equal(1, await UnreadAsync(customer));

        Assert.Equal(HttpStatusCode.OK, (await customer.PostAsync("/api/v1/notifications/read-all", null)).StatusCode);
        Assert.Equal(0, await UnreadAsync(customer));
    }

    private (string Email, HttpClient Client) NewCustomer()
    {
        var id = Interlocked.Increment(ref _nextCustomer);
        var email = $"remind{id}@test.local";
        return (email, _factory.ClientFor(TestJwt.Create(id, email, "ROLE_CUSTOMER")));
    }

    private static long UserIdOf(string email) => long.Parse(email["remind".Length..email.IndexOf('@')]);

    // Vé đã thanh toán; bookedHoursAgo > 0 thì lùi giờ đặt vé (vé đặt từ trước khoảng nhắc)
    private async Task<long> PaidBookingAsync(HttpClient customer, DateTime showStart, int bookedHoursAgo)
    {
        var showtime = _factory.Showtimes.AddShowtime(showStart);
        var id = await CreatePaidBookingAsync(_factory, customer, showtime.Id, NewSeat());
        if (bookedHoursAgo > 0)
        {
            var createdAt = DateTime.Now.AddHours(-bookedHoursAgo);
            await _factory.QueryAsync<BookingDbContext, int>(db => db.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE bookings SET created_at = {createdAt} WHERE id = {id}"));
        }

        return id;
    }

    private Task RemindAsync() =>
        _factory.ExecuteAsync<IBookingService>(service => service.SendShowtimeRemindersAsync(TimeSpan.FromHours(2), 500));

    private Task<DateTime?> RemindedAtAsync(long bookingId) =>
        _factory.QueryAsync<BookingDbContext, DateTime?>(db =>
            db.Bookings.Where(b => b.Id == bookingId).Select(b => b.RemindedAt).SingleAsync());

    private static async Task<int> UnreadAsync(HttpClient customer) =>
        (await customer.GetFromJsonAsync<JsonElement>("/api/v1/notifications/unread-count")).GetProperty("count").GetInt32();
}
