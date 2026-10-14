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

    [Fact]
    public async Task SeatCount_FillsTheLastRowFirstAndRemovesFromTheEnd()
    {
        var roomId = await CreateRoomWithSeatsAsync(rows: 2, seatsPerRow: 3);
        var original = await SeatsAsync(roomId);

        // Staff đổi loại ghế được, nhưng đổi sức chứa phòng là việc của Admin
        Assert.Equal(HttpStatusCode.Forbidden,
            (await _staff.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 10 })).StatusCode);

        var grown = await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 10 });
        Assert.Equal(HttpStatusCode.OK, grown.StatusCode);
        Assert.Equal(
            new[] { "A1", "A2", "A3", "B1", "B2", "B3", "C1", "C2", "C3", "D1" },
            (await grown.Content.ReadFromJsonAsync<JsonElement>()).EnumerateArray().Select(Label));
        Assert.Equal(10, await TotalSeatsAsync(roomId));

        // Hàng mới dài 5 ghế: D lấp tới D5 rồi sang E
        await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 16, seatsPerRow = 5 });
        Assert.Equal(
            new[] { "D1", "D2", "D3", "D4", "D5", "E1", "E2" },
            (await SeatsAsync(roomId)).Skip(9).Select(s => s.Label));

        var shrunk = await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 5 });
        Assert.Equal(HttpStatusCode.OK, shrunk.StatusCode);
        Assert.Equal(5, await TotalSeatsAsync(roomId));
        // Bỏ từ ghế cuối; ghế còn lại không bị đánh số lại
        Assert.Equal(original.Take(5), await SeatsAsync(roomId));
    }

    [Fact]
    public async Task SeatCount_IsRefusedPastRowZAndOnceTheRoomHasShowtimes()
    {
        var roomId = await CreateRoomWithSeatsAsync(rows: 1, seatsPerRow: 2);

        var tooMany = await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 60 });
        Assert.Equal(HttpStatusCode.BadRequest, tooMany.StatusCode);
        Assert.Equal(2, (await SeatsAsync(roomId)).Count);

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

        var locked = await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 4 });
        Assert.Equal(HttpStatusCode.BadRequest, locked.StatusCode);
    }

    [Fact]
    public async Task Sweetbox_SeatsChangeTypeAsAPair()
    {
        var roomId = await CreateRoomWithSeatsAsync(rows: 2, seatsPerRow: 3);
        var ids = (await SeatsAsync(roomId)).ToDictionary(s => s.Label, s => s.Id);

        // Số lẻ ghép với số chẵn bên phải: A1 kéo theo A2
        Assert.Equal(HttpStatusCode.OK, (await SetTypeAsync(ids["A1"], "SWEETBOX")).StatusCode);
        Assert.Equal("SWEETBOX", (await TypesAsync(roomId))["A2"]);

        // A3 không có A4 để ghép đôi
        Assert.Equal(HttpStatusCode.BadRequest, (await SetTypeAsync(ids["A3"], "SWEETBOX")).StatusCode);

        // Đổi một nửa cặp sang ghế đơn thì cả cặp đổi theo
        Assert.Equal(HttpStatusCode.OK, (await SetTypeAsync(ids["A2"], "VIP")).StatusCode);
        var types = await TypesAsync(roomId);
        Assert.Equal(("VIP", "VIP", "NORMAL"), (types["A1"], types["A2"], types["A3"]));

        // Xoá một ghế sweetbox: ghế còn lại của cặp thành ghế thường
        await SetTypeAsync(ids["B2"], "SWEETBOX");
        Assert.Equal("SWEETBOX", (await TypesAsync(roomId))["B1"]);
        Assert.Equal(HttpStatusCode.NoContent, (await _admin.DeleteAsync($"/api/seats/{ids["B1"]}")).StatusCode);
        Assert.Equal("NORMAL", (await TypesAsync(roomId))["B2"]);
        Assert.Equal(5, await TotalSeatsAsync(roomId));
    }

    [Fact]
    public async Task SeatCount_RemovingHalfOfASweetboxLeavesAStandardSeat()
    {
        var roomId = await CreateRoomWithSeatsAsync(rows: 1, seatsPerRow: 4);
        var a3 = (await SeatsAsync(roomId)).Single(s => s.Label == "A3").Id;
        await SetTypeAsync(a3, "SWEETBOX");

        var shrunk = await _admin.PutAsJsonAsync($"/api/seats/room/{roomId}/capacity", new { totalSeats = 3 });
        Assert.Equal(HttpStatusCode.OK, shrunk.StatusCode);
        var types = await TypesAsync(roomId);
        Assert.False(types.ContainsKey("A4"));
        Assert.Equal("NORMAL", types["A3"]);
    }

    [Fact]
    public async Task SeatsForBooking_SweetboxIsBookedInPairs()
    {
        var roomId = await CreateRoomWithSeatsAsync(rows: 1, seatsPerRow: 4);
        var ids = (await SeatsAsync(roomId)).ToDictionary(s => s.Label, s => s.Id);
        await SetTypeAsync(ids["A2"], "SWEETBOX");

        var start = _factory.NextFreeDay();
        var showtime = await _staff.PostAsJsonAsync("/api/showtimes", new
        {
            movieId = _factory.MovieId,
            roomId,
            startTime = start,
            endTime = start.AddHours(2),
            price = 90_000
        });
        var showtimeId = (await showtime.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();

        var half = await _staff.PostAsJsonAsync($"/api/showtimes/{showtimeId}/seats", new[] { ids["A2"] });
        Assert.Equal(HttpStatusCode.BadRequest, half.StatusCode);
        Assert.Contains("A1", await half.Content.ReadAsStringAsync());

        Assert.Equal(HttpStatusCode.OK,
            (await _staff.PostAsJsonAsync($"/api/showtimes/{showtimeId}/seats", new[] { ids["A1"], ids["A2"] })).StatusCode);
        Assert.Equal(HttpStatusCode.OK,
            (await _staff.PostAsJsonAsync($"/api/showtimes/{showtimeId}/seats", new[] { ids["A3"] })).StatusCode);
    }

    private Task<HttpResponseMessage> SetTypeAsync(long seatId, string type) =>
        _staff.PutAsJsonAsync($"/api/seats/{seatId}/type", new { seatIds = new[] { seatId }, seatType = type });

    private async Task<Dictionary<string, string>> TypesAsync(long roomId)
    {
        var seats = await _staff.GetFromJsonAsync<JsonElement>($"/api/seats/room/{roomId}");
        return seats.EnumerateArray().ToDictionary(Label, s => s.GetProperty("seatType").GetString()!);
    }

    private async Task<long> CreateRoomWithSeatsAsync(int rows, int seatsPerRow)
    {
        var room = await _admin.PostAsJsonAsync("/api/rooms", new
        {
            name = $"Seat test room {Guid.NewGuid():N}",
            totalSeats = rows * seatsPerRow,
            rows,
            seatsPerRow
        });
        var roomId = (await room.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
        var generate = await _staff.PostAsJsonAsync("/api/seats/generate", new { roomId, rows, seatsPerRow, seatType = "NORMAL" });
        Assert.Equal(HttpStatusCode.OK, generate.StatusCode);
        return roomId;
    }

    private async Task<List<(long Id, string Label)>> SeatsAsync(long roomId)
    {
        var seats = await _staff.GetFromJsonAsync<JsonElement>($"/api/seats/room/{roomId}");
        return seats.EnumerateArray().Select(s => (s.GetProperty("id").GetInt64(), Label(s))).ToList();
    }

    private async Task<int> TotalSeatsAsync(long roomId)
    {
        var room = await _admin.GetFromJsonAsync<JsonElement>($"/api/rooms/{roomId}");
        return room.GetProperty("totalSeats").GetInt32();
    }

    private static string Label(JsonElement seat) =>
        $"{seat.GetProperty("seatRow").GetString()}{seat.GetProperty("seatNumber").GetInt32()}";
}
