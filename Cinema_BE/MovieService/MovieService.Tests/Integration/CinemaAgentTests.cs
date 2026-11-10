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
