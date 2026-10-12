using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MovieService.Tests.Infrastructure;

namespace MovieService.Tests.Integration;

// Quản lý phim và phòng của Admin: ngừng / chiếu lại phim, đổi tên và xoá phòng
[Collection(MovieApiCollection.Name)]
public class AdminCatalogTests
{
    private readonly MovieApiFactory _factory;
    private readonly HttpClient _staff;
    private readonly HttpClient _admin;

    public AdminCatalogTests(MovieApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(MovieApiFactory.StaffToken);
        _admin = factory.ClientFor(TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN"));
    }

    private static object MovieBody(string title, string? status = null) => new
    {
        title,
        description = "Phim thử",
        durationMinutes = 110,
        genre = "Drama",
        language = "Vietnamese",
        releaseDate = new DateTime(2026, 9, 1),
        posterUrl = "https://example.com/poster.jpg",
        status
    };

    [Fact]
    public async Task StoppedMovie_CanBeShownAgain_ByAdminOnly()
    {
        var title = $"Admin movie {Guid.NewGuid():N}";
        var created = await _admin.PostAsJsonAsync("/api/v1/movies", MovieBody(title));
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var id = (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();

        Assert.Equal(HttpStatusCode.NoContent, (await _admin.DeleteAsync($"/api/v1/movies/{id}")).StatusCode);
        Assert.Equal("INACTIVE", await StatusOfMovieAsync(id));

        // Other fields stay the same when status is left out
        Assert.Equal(HttpStatusCode.OK, (await _admin.PutAsJsonAsync($"/api/v1/movies/{id}", MovieBody(title))).StatusCode);
        Assert.Equal("INACTIVE", await StatusOfMovieAsync(id));

        Assert.Equal(HttpStatusCode.BadRequest,
            (await _admin.PutAsJsonAsync($"/api/v1/movies/{id}", MovieBody(title, "DRAFT"))).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await _staff.PutAsJsonAsync($"/api/v1/movies/{id}", MovieBody(title, "ACTIVE"))).StatusCode);

        var shown = await _admin.PutAsJsonAsync($"/api/v1/movies/{id}", MovieBody(title, "active"));
        Assert.Equal(HttpStatusCode.OK, shown.StatusCode);
        Assert.Equal("ACTIVE", await StatusOfMovieAsync(id));
    }

    [Fact]
    public async Task RenamingRoom_KeepsItsSeats_AndDeleteRemovesSeatsToo()
    {
        var roomId = await CreateRoomWithSeatsAsync($"Admin room {Guid.NewGuid():N}", rows: 2, seatsPerRow: 3);
        var other = await CreateRoomWithSeatsAsync($"Admin room {Guid.NewGuid():N}", rows: 1, seatsPerRow: 2);

        // Rows / seats per row of the request do not override the real seat map
        var newName = $"Renamed room {Guid.NewGuid():N}";
        var renamed = await _admin.PutAsJsonAsync($"/api/rooms/{roomId}", new
        {
            name = newName,
            totalSeats = 1,
            rows = 1,
            seatsPerRow = 1
        });
        Assert.Equal(HttpStatusCode.OK, renamed.StatusCode);
        var room = await renamed.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(newName, room.GetProperty("name").GetString());
        Assert.Equal(6, room.GetProperty("totalSeats").GetInt32());

        var otherName = (await _admin.GetFromJsonAsync<JsonElement>($"/api/rooms/{other}")).GetProperty("name").GetString();
        Assert.Equal(HttpStatusCode.BadRequest, (await _admin.PutAsJsonAsync($"/api/rooms/{roomId}", new
        {
            name = otherName,
            totalSeats = 6,
            rows = 2,
            seatsPerRow = 3
        })).StatusCode);

        Assert.Equal(HttpStatusCode.NoContent, (await _admin.DeleteAsync($"/api/rooms/{roomId}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _admin.GetAsync($"/api/rooms/{roomId}")).StatusCode);
        Assert.Equal(0, await _factory.QueryAsync(db => db.Seats.CountAsync(s => s.RoomId == roomId)));
    }

    [Fact]
    public async Task RoomWithShowtimes_CannotBeDeleted()
    {
        var roomId = await CreateRoomWithSeatsAsync($"Admin room {Guid.NewGuid():N}", rows: 1, seatsPerRow: 4);
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

        Assert.Equal(HttpStatusCode.BadRequest, (await _admin.DeleteAsync($"/api/rooms/{roomId}")).StatusCode);
        Assert.Equal(4, (await _staff.GetFromJsonAsync<JsonElement>($"/api/seats/room/{roomId}")).GetArrayLength());
    }

    private async Task<long> CreateRoomWithSeatsAsync(string name, int rows, int seatsPerRow)
    {
        var created = await _admin.PostAsJsonAsync("/api/rooms", new
        {
            name,
            totalSeats = rows * seatsPerRow,
            rows,
            seatsPerRow
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var roomId = (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
        var seats = await _admin.PostAsJsonAsync("/api/seats/generate", new { roomId, rows, seatsPerRow, seatType = "NORMAL" });
        Assert.Equal(HttpStatusCode.OK, seats.StatusCode);
        return roomId;
    }

    private async Task<string?> StatusOfMovieAsync(long id) =>
        (await _admin.GetFromJsonAsync<JsonElement>($"/api/v1/movies/{id}")).GetProperty("status").GetString();
}
