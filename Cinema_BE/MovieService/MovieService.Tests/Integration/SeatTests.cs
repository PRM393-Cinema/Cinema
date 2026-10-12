using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MovieService.Tests.Infrastructure;

namespace MovieService.Tests.Integration;

// Sơ đồ ghế: sinh ghế một lần, đổi loại ghế khi phòng chưa có suất chiếu
[Collection(MovieApiCollection.Name)]
public class SeatTests
{
    private readonly MovieApiFactory _factory;
    private readonly HttpClient _staff;
    private readonly HttpClient _admin;

    public SeatTests(MovieApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(MovieApiFactory.StaffToken);
        _admin = factory.ClientFor(TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN"));
    }

    [Fact]
    public async Task SeatType_CanChangeUntilTheRoomHasShowtimes()
    {
        var room = await _admin.PostAsJsonAsync("/api/rooms", new
        {
            name = $"Seat test room {Guid.NewGuid():N}",
            totalSeats = 4,
            rows = 2,
            seatsPerRow = 2
        });
        Assert.Equal(HttpStatusCode.Created, room.StatusCode);
        var roomId = (await room.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();

        var generate = new { roomId, rows = 2, seatsPerRow = 2, seatType = "NORMAL" };
        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsJsonAsync("/api/seats/generate", generate)).StatusCode);
        // A second run would duplicate A1..B2
        Assert.Equal(HttpStatusCode.BadRequest, (await _staff.PostAsJsonAsync("/api/seats/generate", generate)).StatusCode);

        var seats = await _staff.GetFromJsonAsync<JsonElement>($"/api/seats/room/{roomId}");
        Assert.Equal(4, seats.GetArrayLength());
        var seatId = seats[0].GetProperty("id").GetInt64();

        var vip = await _staff.PutAsJsonAsync($"/api/seats/{seatId}/type", new { seatIds = new[] { seatId }, seatType = "VIP" });
        Assert.Equal(HttpStatusCode.OK, vip.StatusCode);
        Assert.Equal("VIP", (await vip.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("seatType").GetString());

        var start = _factory.NextFreeDay();
        var showtime = await _staff.PostAsJsonAsync("/api/showtimes", new
        {
            movieId = _factory.MovieId,
            roomId,
            startTime = start,
            endTime = start.AddHours(2),
            price = 90_000
        });
        Assert.Equal(HttpStatusCode.Created, showtime.StatusCode);

        var locked = await _staff.PutAsJsonAsync($"/api/seats/{seatId}/type", new { seatIds = new[] { seatId }, seatType = "NORMAL" });
        Assert.Equal(HttpStatusCode.BadRequest, locked.StatusCode);
    }
}
