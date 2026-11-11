using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MovieService.Chat;
using MovieService.Data;
using MovieService.Models;
using MovieService.Tests.Infrastructure;
using ShowtimeService.Data;
using ShowtimeService.Models;

namespace MovieService.Tests.Integration;

public sealed class CinemaAgentTests(ChatApiFactory factory) : IClassFixture<ChatApiFactory>
{
    [Fact]
    public async Task SnackRecommendations_UsePublicMenuLinksWithoutSendingAccountToken()
    {
        using var scope = factory.Services.CreateScope();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        factory.Accounts.Output = """
            [
              {"id":7,"name":"Combo Couple","description":"Bắp và hai nước","price":57000,"active":true},
              {"id":8,"name":"Old combo","description":null,"price":62000,"active":false}
            ]
            """;
        try
        {
            var result = await tools.ExecuteAsync("get_snack_menu", JsonSerializer.SerializeToElement(new { }), "unused-account-token", default);
            var menu = JsonSerializer.SerializeToElement(result.Result).GetProperty("items");
            Assert.Equal(1, menu.GetArrayLength());
            Assert.Equal("/snacks/7", menu[0].GetProperty("DetailUrl").GetString());
            Assert.Equal(57000m, menu[0].GetProperty("Price").GetDecimal());
            Assert.Equal("/api/v1/concessions", factory.Accounts.LastPath);
            Assert.Null(factory.Accounts.LastAuthorization);
        }
        finally { factory.Accounts.Output = "[]"; }
    }

    [Fact]
    public async Task AccountEndpoint_RequiresJwt_AndGuestToolsNeverForwardTokens()
    {
        using var client = factory.CreateClient();
        var before = factory.Handler.Calls;
        using var denied = await client.PostAsJsonAsync("/api/v1/chat/account", new { messages = new[] { new ChatMessage("user", "My highest bill") } });
        Assert.Equal(HttpStatusCode.Unauthorized, denied.StatusCode);
        Assert.Equal(before, factory.Handler.Calls);
        using var scope = factory.Services.CreateScope();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        foreach (var (name, args) in new[]
        {
            ("get_membership", "{}"), ("get_seats", "{\"showtimeId\":1}"),
            ("get_account_summary", "{\"from\":null,\"to\":null,\"query\":\"\",\"page\":1}"),
            ("prepare_booking", "{\"showtimeId\":1,\"seatIds\":[1]}")
        })
        {
            var calls = factory.Accounts.Calls;
            var result = await tools.ExecuteAsync(name, JsonSerializer.Deserialize<JsonElement>(args), null, default);
            Assert.Contains("SIGN_IN_REQUIRED", JsonSerializer.Serialize(result.Result));
            Assert.Null(result.Proposal);
            Assert.Equal(calls, factory.Accounts.Calls);
        }
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("get_membership",
            JsonSerializer.Deserialize<JsonElement>("{\"userId\":999}"), "token", default));
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("delete_booking",
            JsonSerializer.Deserialize<JsonElement>("{}"), "token", default));
    }

    [Fact]
    public async Task ToolLoop_UsesServerFacts_AndForwardsLoginOnlyToTrustedAccountApi()
    {
        var token = TestJwt.Create(101, "private@test.local", "ROLE_CUSTOMER");
        using var client = factory.ClientFor(token);
        factory.Accounts.Output = "{\"tier\":\"VIP\",\"points\":123,\"userId\":101,\"email\":\"private@test.local\"}";
        factory.Handler.Outputs.Enqueue(ToolCall("get_membership", new { }));
        try
        {
            using var response = await client.PostAsJsonAsync("/api/v1/chat/account", new { messages = new[] { new ChatMessage("user", "Hạng của tôi?") } });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Equal("Bearer " + token, factory.Accounts.LastAuthorization);
            Assert.Equal("/api/v1/loyalty/me", factory.Accounts.LastPath);
            using var body = JsonDocument.Parse(factory.Handler.LastBody!);
            var input = body.RootElement.GetProperty("input").ToString();
            Assert.Contains("VIP", input);
            Assert.Contains("123", input);
            Assert.Contains("function_call_output", input);
            Assert.DoesNotContain(token, input);
            Assert.DoesNotContain("private@test.local", input);
            Assert.DoesNotContain("userId", input);
            Assert.Equal("Bearer test-openai-key", factory.Handler.LastAuthorization);
        }
        finally { factory.Accounts.Output = "[]"; factory.Handler.Outputs.Clear(); }
    }

    [Fact]
    public async Task Search_RetrievesBeyondInitialSnapshot_WithPagingAndDateFiltering()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MovieDbContext>();
        for (var i = 0; i < 35; i++) db.Movies.Add(new Movie { Title = $"Agent search {i:D2}", Status = "ACTIVE", DurationMinutes = 90 });
        db.Movies.Add(new Movie { Title = "Agent search hidden", Status = "INACTIVE", DurationMinutes = 90 });
        await db.SaveChangesAsync();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        var result = await tools.ExecuteAsync("search_movies", JsonSerializer.SerializeToElement(new { query = "Agent search", page = 2 }), null, default);
        var json = JsonSerializer.SerializeToElement(result.Result);
        Assert.Equal(35, json.GetProperty("count").GetInt32());
        Assert.Equal(15, json.GetProperty("items").GetArrayLength());
        foreach (var movie in json.GetProperty("items").EnumerateArray())
            Assert.Equal($"/movies/{movie.GetProperty("Id").GetInt64()}", movie.GetProperty("DetailUrl").GetString());
        Assert.DoesNotContain("hidden", json.ToString());
        var session = await NewSession();
        var date = session.StartTime.ToString("yyyy-MM-dd");
        var schedule = await tools.ExecuteAsync("find_showtimes", JsonSerializer.SerializeToElement(new { movieId = factory.MovieId, from = date, to = date, page = 1 }), null, default);
        Assert.Contains(session.Id.ToString(), JsonSerializer.Serialize(schedule.Result));
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("find_showtimes",
            JsonSerializer.Deserialize<JsonElement>("{\"movieId\":1,\"from\":\"bad\",\"to\":null,\"page\":1}"), null, default));
    }

    [Fact]
    public async Task CinemaShowtimes_SkipPastAndFullSessions_AndMatchTheBookingTimeAndRoom()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ShowtimeDbContext>();
        var now = CinemaChatToolsTestNow();
        var day = now.Date.AddDays(1);
        var past = Session(now.AddHours(-2));
        var full = Session(day.AddHours(18));
        var early = Session(day.AddHours(19));
        var closest = Session(day.AddHours(20));
        db.Showtimes.AddRange(past, full, early, closest);
        await db.SaveChangesAsync();
        var capacity = await db.Seats.CountAsync(seat => seat.RoomId == factory.RoomId);
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        factory.Accounts.Output = JsonSerializer.Serialize(new[]
        {
            new { ShowtimeId = full.Id, OccupiedSeats = capacity },
            new { ShowtimeId = early.Id, OccupiedSeats = capacity - 3 },
            new { ShowtimeId = closest.Id, OccupiedSeats = capacity - 2 }
        });
        try
        {
            var tomorrow = day.ToString("yyyy-MM-dd");
            var date = now.ToString("yyyy-MM-dd");
            var nearest = await Call("CosmoQ", "Phòng Test", date, tomorrow, null, 1);
            Assert.Equal(new[] { early.Id, closest.Id }, nearest.EnumerateArray().Select(item => item.GetProperty("Id").GetInt64()));
            var booking = await Call("CosmoQ", "Phòng Test", tomorrow, tomorrow, "20:00", 2);
            Assert.Equal($"/showtimes/{closest.Id}/seats", booking[0].GetProperty("SeatUrl").GetString());
            Assert.Equal(2, booking[0].GetProperty("AvailableSeats").GetInt32());
            var beforeRequestedTime = await Call("CosmoQ", "Phòng Test", tomorrow, tomorrow, "19:10", 2);
            Assert.Equal(early.Id, beforeRequestedTime[0].GetProperty("Id").GetInt64());
            Assert.Empty((await Call("CosmoQ", "Phòng Test", tomorrow, tomorrow, "20:00", 4)).EnumerateArray());
            Assert.Empty((await Call("Rạp khác", "Phòng Test", tomorrow, tomorrow, null, 1)).EnumerateArray());
            Assert.Empty((await Call("CosmoQ", "Phòng không tồn tại", tomorrow, tomorrow, null, 1)).EnumerateArray());
            Assert.Null(factory.Accounts.LastAuthorization);
        }
        finally { factory.Accounts.Output = "[]"; }

        Showtime Session(DateTime start) => new()
        {
            MovieId = factory.MovieId, RoomId = factory.RoomId, StartTime = start,
            EndTime = start.AddHours(1), Status = "OPEN", Price = 100000
        };

        async Task<JsonElement> Call(string cinema, string room, string from, string to, string? around, int tickets)
        {
            var result = await tools.ExecuteAsync("find_cinema_showtimes", JsonSerializer.SerializeToElement(new
            {
                movieIds = new[] { factory.MovieId }, genre = "", cinema, room, from, to, around, tickets
            }), "unused-account-token", default);
            return JsonSerializer.SerializeToElement(result.Result).GetProperty("Items");
        }
    }

    [Fact]
    public async Task TopRated_WeightsReviewVolume_AndExcludesUnreleasedFilms()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MovieDbContext>();
        var wellReviewed = new Movie { Title = "Many reviews", DurationMinutes = 90, Status = "ACTIVE" };
        var unreleased = new Movie
        {
            Title = "Future release", DurationMinutes = 90, Status = "ACTIVE",
            ReleaseDate = DateOnly.FromDateTime(CinemaChatToolsTestNow().AddDays(2))
        };
        db.Movies.AddRange(wellReviewed, unreleased);
        await db.SaveChangesAsync();
        factory.Accounts.Output = JsonSerializer.Serialize(new[]
        {
            new { MovieId = factory.MovieId, Average = 5.0, Count = 1 },
            new { MovieId = wellReviewed.Id, Average = 4.7, Count = 100 },
            new { MovieId = unreleased.Id, Average = 5.0, Count = 1000 }
        });
        try
        {
            var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
            var result = await tools.ExecuteAsync("get_top_rated_movies", JsonSerializer.SerializeToElement(new { }), null, default);
            var items = JsonSerializer.SerializeToElement(result.Result).GetProperty("items");
            Assert.Equal(2, items.GetArrayLength());
            Assert.Equal($"/movies/{wellReviewed.Id}", items[0].GetProperty("DetailUrl").GetString());
            Assert.Equal(100, items[0].GetProperty("ReviewCount").GetInt32());
        }
        finally { factory.Accounts.Output = "[]"; }
    }

    [Fact]
    public async Task Trending_AggregatesSessionsByFilm_AndComparesTicketWindows()
    {
        var first = await NewSession();
        var second = await NewSession();
        using var scope = factory.Services.CreateScope();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        factory.Accounts.Output = JsonSerializer.Serialize(new[]
        {
            new { ShowtimeId = first.Id, RecentBookings = 3, RecentTickets = 5, PreviousBookings = 1, PreviousTickets = 2 },
            new { ShowtimeId = second.Id, RecentBookings = 2, RecentTickets = 4, PreviousBookings = 1, PreviousTickets = 1 }
        });
        try
        {
            var result = await tools.ExecuteAsync("get_trending_movies", JsonSerializer.SerializeToElement(new { }), null, default);
            var row = Assert.Single(JsonSerializer.SerializeToElement(result.Result).GetProperty("items").EnumerateArray());
            Assert.Equal(9, row.GetProperty("Tickets").GetInt32());
            Assert.Equal(5, row.GetProperty("Bookings").GetInt32());
            Assert.Equal(200.0, row.GetProperty("TicketGrowthPercent").GetDouble());
            Assert.Equal($"/movies/{factory.MovieId}", row.GetProperty("DetailUrl").GetString());
        }
        finally { factory.Accounts.Output = "[]"; }
    }

    [Fact]
    public async Task MovieCandidates_FilterGenreAgeAndDuration_AndProvideSynopsisForPreferenceMatching()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MovieDbContext>();
        Movie Film(string title, string genre, int minutes, string age) => new()
        {
            Title = title, Genre = genre, DurationMinutes = minutes, AgeRating = age,
            Status = "ACTIVE", Description = "Suspense and a family mystery"
        };
        db.Movies.AddRange(Film("One", "Mystery QA", 90, "T13"), Film("Two", "Mystery QA", 95, "T16"),
            Film("Three", "Mystery QA", 100, "P"), Film("Too long", "Mystery QA", 140, "T13"),
            Film("Too old", "Mystery QA", 95, "T18"), Film("Other genre", "Comedy QA", 95, "T13"));
        await db.SaveChangesAsync();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        var result = await tools.ExecuteAsync("get_movie_candidates", JsonSerializer.SerializeToElement(new
        {
            genre = "Mystery QA", maxAgeRating = "T16", minMinutes = 90, maxMinutes = 100
        }), null, default);
        var payload = JsonSerializer.SerializeToElement(result.Result);
        Assert.Equal(3, payload.GetProperty("count").GetInt32());
        Assert.False(payload.GetProperty("contentAdvisoriesAvailable").GetBoolean());
        Assert.All(payload.GetProperty("items").EnumerateArray(), item =>
        {
            Assert.Equal("Suspense and a family mystery", item.GetProperty("Description").GetString());
            Assert.StartsWith("/movies/", item.GetProperty("DetailUrl").GetString());
        });
    }

    private static DateTime CinemaChatToolsTestNow() =>
        TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, "Asia/Ho_Chi_Minh").DateTime;

    [Fact]
    public async Task PrepareBooking_RechecksSeatsAndComputesPrice_WithoutCreatingAnything()
    {
        var session = await NewSession();
        using var scope = factory.Services.CreateScope();
        var tools = scope.ServiceProvider.GetRequiredService<CinemaChatTools>();
        var db = scope.ServiceProvider.GetRequiredService<ShowtimeDbContext>();
        var originalCount = await db.Showtimes.CountAsync();
        var result = await tools.ExecuteAsync("prepare_booking", JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = factory.SeatIds.Take(2) }), "login-token", default);
        Assert.NotNull(result.Proposal);
        Assert.Equal(240000, result.Proposal.Total); // 2 x (100,000 + 3D 20,000)
        Assert.Equal(2, result.Proposal.SeatIds.Length);
        Assert.True(result.Proposal.ExpiresAt > DateTimeOffset.UtcNow);
        Assert.Equal(originalCount, await db.Showtimes.CountAsync());
        factory.Accounts.Output = JsonSerializer.Serialize(new[] { factory.SeatIds[0] });
        try
        {
            await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("prepare_booking",
                JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = factory.SeatIds.Take(2) }), "login-token", default));
        }
        finally { factory.Accounts.Output = "[]"; }
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("prepare_booking",
            JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = new[] { factory.OtherRoomSeatId } }), "login-token", default));
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("prepare_booking",
            JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = new[] { factory.SeatIds[0], factory.SeatIds[0] } }), "login-token", default));
        db.Seats.AddRange(new Seat { RoomId = factory.RoomId, SeatRow = "S", SeatNumber = 1, SeatType = "SWEETBOX" },
            new Seat { RoomId = factory.RoomId, SeatRow = "S", SeatNumber = 2, SeatType = "SWEETBOX" });
        await db.SaveChangesAsync();
        var sweetbox = await db.Seats.Where(s => s.SeatRow == "S").OrderBy(s => s.SeatNumber).Select(s => s.Id).ToArrayAsync();
        await Assert.ThrowsAsync<ArgumentException>(() => tools.ExecuteAsync("prepare_booking",
            JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = sweetbox.Take(1) }), "login-token", default));
        var paired = await tools.ExecuteAsync("prepare_booking", JsonSerializer.SerializeToElement(new { showtimeId = session.Id, seatIds = sweetbox }), "login-token", default);
        Assert.Equal(312000, paired.Proposal!.Total);
    }

    [Fact]
    public async Task Proposal_IsStructured_AndNeverDelegatesConfirmationToModelText()
    {
        var session = await NewSession();
        using var client = factory.ClientFor(TestJwt.Create(101, "private@test.local", "ROLE_CUSTOMER"));
        factory.Handler.Outputs.Enqueue(ToolCall("prepare_booking", new { showtimeId = session.Id, seatIds = factory.SeatIds.Take(1) }));
        try
        {
            using var response = await client.PostAsJsonAsync("/api/v1/chat/account", new { messages = new[] { new ChatMessage("user", "Đặt ghế A1") } });
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var reply = await response.Content.ReadFromJsonAsync<ChatReply>();
            Assert.Equal(120000, reply!.Booking!.Total);
            Assert.Contains("Chưa giữ ghế", reply.Message);
        }
        finally { factory.Handler.Outputs.Clear(); }
    }

    [Fact]
    public async Task RepeatedToolCalls_StopAtTheBudget()
    {
        using var client = factory.CreateClient();
        factory.Handler.Output = ToolCall("search_movies", new { query = "test", page = 1 });
        var before = factory.Handler.Calls;
        try
        {
            using var response = await client.PostAsJsonAsync("/api/v1/chat", new { messages = new[] { new ChatMessage("user", "Find movies") } });
            Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
            Assert.Equal(5, factory.Handler.Calls - before);
        }
        finally { factory.Handler.Output = null; }
    }

    [Fact]
    public async Task SeatLink_RequiresAvailabilityFromThisTurn()
    {
        using var client = factory.CreateClient();
        factory.Handler.Output = JsonSerializer.Serialize(new
        {
            status = "completed",
            output = new[] { new { type = "message", content = new[]
                { new { type = "output_text", text = "[Chọn ghế](/showtimes/123/seats)" } } } }
        });
        try
        {
            using var response = await client.PostAsJsonAsync("/api/v1/chat", new
            {
                messages = new[] { new ChatMessage("user", "Cho tôi link đặt vé") }
            });
            response.EnsureSuccessStatusCode();
            Assert.Equal("Chọn ghế", (await response.Content.ReadFromJsonAsync<ChatReply>())!.Message);
        }
        finally { factory.Handler.Output = null; }
    }

    [Fact]
    public async Task MissingBookingDetails_ReturnPrefilledFormWithoutBooking()
    {
        using var client = factory.CreateClient();
        factory.Handler.Outputs.Enqueue(ToolCall("request_booking_details", new
        {
            movie = "Ma Xó", date = (string?)null, time = (string?)null, tickets = 2
        }));
        try
        {
            var before = factory.Accounts.Calls;
            using var response = await client.PostAsJsonAsync("/api/v1/chat", new
            {
                messages = new[] { new ChatMessage("user", "Đặt giúp 2 vé Ma Xó") }
            });
            response.EnsureSuccessStatusCode();
            var reply = await response.Content.ReadFromJsonAsync<ChatReply>();
            Assert.Equal(new ChatBookingForm("Ma Xó", null, null, 2), reply!.BookingForm);
            Assert.Null(reply.Booking);
            Assert.Equal(before, factory.Accounts.Calls);
        }
        finally { factory.Handler.Outputs.Clear(); }
    }

    private async Task<Showtime> NewSession()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ShowtimeDbContext>();
        var now = TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, "Asia/Ho_Chi_Minh").DateTime;
        var session = new Showtime { MovieId = factory.MovieId, RoomId = factory.RoomId, StartTime = now.AddDays(20),
            EndTime = now.AddDays(20).AddHours(2), Status = "OPEN", Price = 100000, Format = "3D" };
        db.Showtimes.Add(session);
        await db.SaveChangesAsync();
        return session;
    }

    private static string ToolCall(string name, object arguments) => JsonSerializer.Serialize(new
    {
        status = "completed", output = new[] { new { type = "function_call", name, call_id = "test-call", arguments = JsonSerializer.Serialize(arguments) } }
    });
}
