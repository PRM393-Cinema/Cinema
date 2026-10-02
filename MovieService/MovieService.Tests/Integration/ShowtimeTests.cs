using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MovieService.Messaging;
using MovieService.Tests.Infrastructure;
using ShowtimeService.Models;

namespace MovieService.Tests.Integration;

// Suất chiếu (FR-SHOW-01..09): quyền, trùng lịch 409, suất còn đặt được, huỷ mềm + event showtime.cancelled
[Collection(MovieApiCollection.Name)]
public class ShowtimeTests
{
    private readonly MovieApiFactory _factory;
    private readonly HttpClient _staff;

    public ShowtimeTests(MovieApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(MovieApiFactory.StaffToken);
    }

    private async Task<JsonElement> CreateShowtimeAsync(DateTime start, string? status = null)
    {
        var response = await _staff.PostAsJsonAsync("/api/showtimes", new
        {
            movieId = _factory.MovieId,
            roomId = _factory.RoomId,
            startTime = start,
            endTime = start.AddHours(2),
            price = 90_000,
            status
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private async Task<List<long>> OpenShowtimeIdsOfMovieAsync()
    {
        var page = await _factory.CreateClient()
            .GetFromJsonAsync<JsonElement>($"/api/showtimes/movie/{_factory.MovieId}/open?pageSize=50");

        return page.GetProperty("items").EnumerateArray().Select(item => item.GetProperty("id").GetInt64()).ToList();
    }

    [Fact]
    public async Task Browsing_IsPublic_ButChangesNeedStaff()
    {
        var anonymous = _factory.CreateClient();
        var body = new
        {
            movieId = _factory.MovieId,
            roomId = _factory.RoomId,
            startTime = _factory.NextFreeDay(),
            endTime = _factory.NextFreeDay(),
            price = 1
        };

        Assert.Equal(HttpStatusCode.OK, (await anonymous.GetAsync("/api/showtimes/open")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.PostAsJsonAsync("/api/showtimes", body)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await _factory.ClientFor(MovieApiFactory.CustomerToken)
            .PostAsJsonAsync("/api/showtimes", body)).StatusCode);
    }

    [Fact]
    public async Task CreateShowtime_DefaultsToOpen_AndOverlapInSameRoomReturns409()
    {
        var start = _factory.NextFreeDay();
        var showtime = await CreateShowtimeAsync(start);

        Assert.Equal("OPEN", showtime.GetProperty("status").GetString());

        var overlap = await _staff.PostAsJsonAsync("/api/showtimes", new
        {
            movieId = _factory.MovieId,
            roomId = _factory.RoomId,
            startTime = start.AddHours(1),
            endTime = start.AddHours(3),
            price = 90_000
        });

        Assert.Equal(HttpStatusCode.Conflict, overlap.StatusCode);
    }

    [Fact]
    public async Task OpenShowtimesByMovie_OnlyListsBookableOnes()
    {
        var day = _factory.NextFreeDay();
        var open = (await CreateShowtimeAsync(day)).GetProperty("id").GetInt64();
        var closed = (await CreateShowtimeAsync(day.AddHours(3))).GetProperty("id").GetInt64();
        var cancelled = (await CreateShowtimeAsync(day.AddHours(6))).GetProperty("id").GetInt64();

        Assert.Equal(HttpStatusCode.OK,
            (await _staff.PatchAsJsonAsync($"/api/showtimes/{closed}/status", new { status = "CLOSED" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _staff.DeleteAsync($"/api/showtimes/{cancelled}")).StatusCode);

        // Suất đã chiếu (ghi thẳng vào DB vì API không cho tạo suất trong quá khứ hợp lệ)
        var past = await _factory.QueryAsync(async db =>
        {
            var showtime = new Showtime
            {
                MovieId = _factory.MovieId,
                RoomId = _factory.RoomId,
                StartTime = DateTime.Now.AddDays(-1),
                EndTime = DateTime.Now.AddDays(-1).AddHours(2),
                Price = 90_000,
                Status = "OPEN"
            };
            db.Showtimes.Add(showtime);
            await db.SaveChangesAsync();
            return showtime.Id;
        });

        var ids = await OpenShowtimeIdsOfMovieAsync();

        Assert.Contains(open, ids);
        Assert.DoesNotContain(closed, ids);
        Assert.DoesNotContain(cancelled, ids);
        Assert.DoesNotContain(past, ids);
    }

    [Fact]
    public async Task CancelShowtime_KeepsRow_WritesEvent_AndFreesTheRoom()
    {
        var start = _factory.NextFreeDay();
        var id = (await CreateShowtimeAsync(start)).GetProperty("id").GetInt64();

        var cancel = await _staff.DeleteAsync($"/api/showtimes/{id}");
        Assert.Equal(HttpStatusCode.OK, cancel.StatusCode);
        Assert.Equal("CANCELLED", (await cancel.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        // Không xoá dòng: booking của khách vẫn trỏ tới suất chiếu này
        Assert.Equal("CANCELLED", await _factory.QueryAsync(db =>
            db.Showtimes.Where(s => s.Id == id).Select(s => s.Status).SingleAsync()));

        // Event showtime.cancelled nằm trong outbox, cùng lần lưu với trạng thái mới
        var payloads = await _factory.QueryAsync(db => db.Set<OutboxMessage>()
            .Where(message => message.EventType == EventTypes.ShowtimeCancelled)
            .Select(message => message.Payload)
            .ToListAsync());
        Assert.Contains(payloads, payload => payload.Contains($"\"showtimeId\":{id},"));

        Assert.Equal(HttpStatusCode.Conflict, (await _staff.DeleteAsync($"/api/showtimes/{id}")).StatusCode);

        // Suất đã huỷ không còn chiếm phòng
        await CreateShowtimeAsync(start);
    }

    [Fact]
    public async Task UpdateWithoutStatus_KeepsStatus_AndCancelledShowtimeIsReadOnly()
    {
        var start = _factory.NextFreeDay();
        var id = (await CreateShowtimeAsync(start, status: "CLOSED")).GetProperty("id").GetInt64();
        var update = new
        {
            movieId = _factory.MovieId,
            roomId = _factory.RoomId,
            startTime = start,
            endTime = start.AddHours(2),
            price = 120_000
        };

        var updated = await _staff.PutAsJsonAsync($"/api/showtimes/{id}", update);
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        Assert.Equal("CLOSED", (await updated.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("status").GetString());

        Assert.Equal(HttpStatusCode.BadRequest,
            (await _staff.PatchAsJsonAsync($"/api/showtimes/{id}/status", new { status = "CANCELLED" })).StatusCode);

        await _staff.DeleteAsync($"/api/showtimes/{id}");
        Assert.Equal(HttpStatusCode.Conflict, (await _staff.PutAsJsonAsync($"/api/showtimes/{id}", update)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict,
            (await _staff.PatchAsJsonAsync($"/api/showtimes/{id}/status", new { status = "OPEN" })).StatusCode);
    }

    [Fact]
    public async Task SeatsForBooking_RejectClosedShowtimeAndSeatsOfAnotherRoom()
    {
        var customer = _factory.ClientFor(MovieApiFactory.CustomerToken);
        var start = _factory.NextFreeDay();
        var id = (await CreateShowtimeAsync(start)).GetProperty("id").GetInt64();

        var seats = await customer.PostAsJsonAsync($"/api/showtimes/{id}/seats", _factory.SeatIds.Take(2));
        Assert.Equal(HttpStatusCode.OK, seats.StatusCode);
        var labels = (await seats.Content.ReadFromJsonAsync<JsonElement>())
            .EnumerateArray().Select(seat => seat.GetProperty("seatLabel").GetString());
        Assert.Equal(new[] { "A1", "A2" }, labels);

        Assert.Equal(HttpStatusCode.BadRequest, (await customer.PostAsJsonAsync(
            $"/api/showtimes/{id}/seats", new[] { _factory.OtherRoomSeatId })).StatusCode);

        await _staff.PatchAsJsonAsync($"/api/showtimes/{id}/status", new { status = "CLOSED" });
        Assert.Equal(HttpStatusCode.BadRequest, (await customer.PostAsJsonAsync(
            $"/api/showtimes/{id}/seats", _factory.SeatIds.Take(1))).StatusCode);
    }
}
