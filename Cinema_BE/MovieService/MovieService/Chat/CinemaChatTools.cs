using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MovieService.Data;
using MovieService.Helpers;
using ShowtimeService.Data;

namespace MovieService.Chat;

public sealed record ChatBookingProposal(long MovieId, long ShowtimeId, string MovieTitle, DateTime StartTime,
    long[] SeatIds, string[] SeatLabels, decimal Total, DateTimeOffset ExpiresAt);

public sealed class CinemaChatTools(MovieDbContext movies, ShowtimeDbContext showtimes, IHttpClientFactory clients)
{
    public static readonly JsonElement Definitions = JsonSerializer.Deserialize<JsonElement>("""
        [
          {"type":"function","name":"search_movies","description":"Search ALL active movies by title, genre or description, paginated. Empty query browses all. Not restricted to the initial snapshot.","strict":true,"parameters":{"type":"object","properties":{"query":{"type":"string","maxLength":100},"page":{"type":"integer","minimum":1,"maximum":10000}},"required":["query","page"],"additionalProperties":false}},
          {"type":"function","name":"find_showtimes","description":"Find live OPEN future showtimes for an active movie. Dates are inclusive Vietnam calendar days; null means now through the next 7 days. Follow pages when necessary.","strict":true,"parameters":{"type":"object","properties":{"movieId":{"type":"integer","minimum":1},"from":{"type":["string","null"]},"to":{"type":["string","null"]},"page":{"type":"integer","minimum":1,"maximum":10000}},"required":["movieId","from","to","page"],"additionalProperties":false}},
          {"type":"function","name":"get_seats","description":"Get live seat ids, labels, types, prices and availability. Sign-in required. Never guess seat ids. SWEETBOX seats must be selected with their adjacent pair.","strict":true,"parameters":{"type":"object","properties":{"showtimeId":{"type":"integer","minimum":1}},"required":["showtimeId"],"additionalProperties":false}},
          {"type":"function","name":"get_membership","description":"Read the signed-in customer's membership tier, points, benefits and recent points history. Requires sign-in; no userId parameter.","strict":true,"parameters":{"type":"object","properties":{},"required":[],"additionalProperties":false}},
          {"type":"function","name":"get_account_summary","description":"Read the signed-in customer's bookings, payments, highest paid bill and exact spending totals across ALL history in the date range. Dates inclusive YYYY-MM-DD Vietnam time; null means all time. Query filters booking code/movie title and payment code, not totals. Page rows in batches of 10. Requires sign-in.","strict":true,"parameters":{"type":"object","properties":{"from":{"type":["string","null"]},"to":{"type":["string","null"]},"query":{"type":"string","maxLength":100},"page":{"type":"integer","minimum":1,"maximum":10000}},"required":["from","to","query","page"],"additionalProperties":false}},
          {"type":"function","name":"prepare_booking","description":"Prepare ONE read-only ticket proposal using exact live seat ids after the customer chooses the movie, showtime and seats. Does NOT hold seats or create/pay a booking. UI shows a review button; customer must confirm there. No snacks, promotions or points applied yet; those are chosen in existing checkout. Sign-in required. Max 8 seats.","strict":true,"parameters":{"type":"object","properties":{"showtimeId":{"type":"integer","minimum":1},"seatIds":{"type":"array","items":{"type":"integer","minimum":1},"minItems":1,"maxItems":8}},"required":["showtimeId","seatIds"],"additionalProperties":false}}
        ]
        """);

    public async Task<(object Result, ChatBookingProposal? Proposal)> ExecuteAsync(string name, JsonElement args,
        string? accessToken, CancellationToken cancellationToken)
    {
        var schema = Definitions.EnumerateArray().FirstOrDefault(t => t.GetProperty("name").GetString() == name);
        if (schema.ValueKind == JsonValueKind.Undefined || args.ValueKind != JsonValueKind.Object)
            throw new ArgumentException("Unknown tool or invalid arguments.");
        var keys = schema.GetProperty("parameters").GetProperty("required").EnumerateArray().Select(v => v.GetString()!).ToArray();
        if (args.EnumerateObject().Any(p => !keys.Contains(p.Name)) || keys.Any(k => !args.TryGetProperty(k, out _)))
            throw new ArgumentException("Use exactly the declared tool arguments.");
        var now = TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, "Asia/Ho_Chi_Minh").DateTime;
        if (name is "get_membership" or "get_account_summary" or "get_seats" or "prepare_booking" && accessToken is null)
            return (new { error = "SIGN_IN_REQUIRED", message = "Sign in before accessing your account or seat availability." }, null);
        switch (name)
        {
            case "search_movies":
                {
                    var term = Text(args, "query").ToLowerInvariant();
                    var page = Page(args);
                    var query = movies.Movies.AsNoTracking().Where(m => m.Status == "ACTIVE");
                    if (term.Length > 0) query = query.Where(m => m.Title.ToLower().Contains(term) ||
                        (m.Genre != null && m.Genre.ToLower().Contains(term)) || (m.Description != null && m.Description.ToLower().Contains(term)));
                    var count = await query.CountAsync(cancellationToken);
                    var items = await query.OrderBy(m => m.Title).ThenBy(m => m.Id).Skip((page - 1) * 20).Take(20)
                        .Select(m => new
                        {
                            m.Id,
                            m.Title,
                            m.Genre,
                            m.Language,
                            m.DurationMinutes,
                            m.AgeRating,
                            m.ReleaseDate,
                            Description = m.Description == null ? null : m.Description.Substring(0, Math.Min(m.Description.Length, 300))
                        })
                        .ToListAsync(cancellationToken);
                    return (new { count, page, pageSize = 20, items }, null);
                }
            case "find_showtimes":
                {
                    var movieId = Id(args, "movieId");
                    if (!await movies.Movies.AnyAsync(m => m.Id == movieId && m.Status == "ACTIVE", cancellationToken))
                        throw new ArgumentException("Movie is not active or does not exist.");
                    var (from, to) = Dates(args);
                    var start = from?.ToDateTime(TimeOnly.MinValue) ?? now;
                    var end = to?.AddDays(1).ToDateTime(TimeOnly.MinValue) ?? start.AddDays(7);
                    if (end <= start) throw new ArgumentException("Invalid date range.");
                    var page = Page(args);
                    var query = showtimes.Showtimes.AsNoTracking().Where(s => s.MovieId == movieId && s.Status == "OPEN" &&
                        s.StartTime > now && s.StartTime >= start && s.StartTime < end);
                    var count = await query.CountAsync(cancellationToken);
                    var items = await query.OrderBy(s => s.StartTime).ThenBy(s => s.Id).Skip((page - 1) * 20).Take(20)
                        .Select(s => new { s.Id, s.MovieId, s.StartTime, s.Format, Room = s.Room.Name, s.Price }).ToListAsync(cancellationToken);
                    return (new
                    {
                        count,
                        page,
                        pageSize = 20,
                        timeZone = "Asia/Ho_Chi_Minh",
                        items = items.Select(s => new
                        { s.Id, s.MovieId, s.StartTime, s.Format, s.Room, seatPrices = SeatPrices.Of(s.Price, s.Format) })
                    }, null);
                }
            case "get_membership":
                {
                    var card = await ReadAccountAsync("api/v1/loyalty/me", accessToken!, cancellationToken);
                    if (!card.TryGetProperty("tier", out _)) return (card, null);
                    // Exclude identity/email; send only the facts needed to answer membership questions.
                    var allowed = new[] { "tier", "points", "pointValue", "lifetimeSpend", "earnRatePercent", "nextTier", "nextTierSpend", "gifts", "transactions" };
                    var facts = card.EnumerateObject().Where(p => allowed.Contains(p.Name)).ToDictionary(p => p.Name, p => p.Value.Clone());
                    if (facts.TryGetValue("transactions", out var transactions) && transactions.ValueKind == JsonValueKind.Array)
                        facts["transactions"] = JsonSerializer.SerializeToElement(transactions.EnumerateArray().Take(50).Select(t =>
                            t.EnumerateObject().Where(p => p.Name is "type" or "points" or "bookingId" or "createdAt")
                                .ToDictionary(p => p.Name, p => p.Value.Clone())));
                    return (facts, null);
                }
            case "get_account_summary":
                {
                    var (from, to) = Dates(args);
                    var query = Uri.EscapeDataString(Text(args, "query"));
                    var path = $"api/v1/bookings/assistant-summary?page={Page(args)}&query={query}";
                    if (from.HasValue) path += $"&from={from:yyyy-MM-dd}";
                    if (to.HasValue) path += $"&to={to:yyyy-MM-dd}";
                    return (await ReadAccountAsync(path, accessToken!, cancellationToken), null);
                }
            default:
                {
                    var id = Id(args, "showtimeId");
                    var session = await showtimes.Showtimes.AsNoTracking().SingleOrDefaultAsync(s => s.Id == id && s.Status == "OPEN" && s.StartTime > now, cancellationToken)
                        ?? throw new ArgumentException("Showtime is no longer open for booking.");
                    var movie = await movies.Movies.AsNoTracking().SingleOrDefaultAsync(m => m.Id == session.MovieId && m.Status == "ACTIVE", cancellationToken)
                        ?? throw new ArgumentException("Movie is no longer active.");
                    var occupied = await ReadAccountAsync($"api/v1/bookings/showtime/{id}/occupied-seats", accessToken!, cancellationToken);
                    if (occupied.ValueKind != JsonValueKind.Array) return (occupied, null);
                    var occupiedIds = occupied.EnumerateArray().Select(v => v.GetInt64()).ToHashSet();
                    var seats = await showtimes.Seats.AsNoTracking().Where(s => s.RoomId == session.RoomId)
                        .OrderBy(s => s.SeatRow).ThenBy(s => s.SeatNumber).ToListAsync(cancellationToken);
                    if (name == "get_seats") return (new
                    {
                        showtimeId = id,
                        movie.Title,
                        session.StartTime,
                        currency = "VND",
                        timeZone = "Asia/Ho_Chi_Minh",
                        availabilityIsSnapshot = true,
                        seats = seats.Select(s => new
                        {
                            s.Id,
                            label = SeatPairs.Label(s),
                            type = s.SeatType,
                            price = SeatPrices.For(session.Price, s.SeatType, session.Format),
                            available = !occupiedIds.Contains(s.Id)
                        })
                    }, null);
                    var values = args.GetProperty("seatIds");
                    if (values.ValueKind != JsonValueKind.Array || values.GetArrayLength() is < 1 or > 8)
                        throw new ArgumentException("Choose 1 to 8 seats.");
                    var ids = values.EnumerateArray().Select(v => v.TryGetInt64(out var seatId) && seatId > 0 ? seatId : throw new ArgumentException("Invalid seat id.")).ToArray();
                    if (ids.Distinct().Count() != ids.Length) throw new ArgumentException("Duplicate seats are not allowed.");
                    var selected = seats.Where(s => ids.Contains(s.Id)).ToArray();
                    if (selected.Length != ids.Length || ids.Any(occupiedIds.Contains)) throw new ArgumentException("Some seats are unavailable. Refresh the seat map.");
                    if (selected.Any(s => SeatPairs.IsSweetbox(s.SeatType) && !ids.Contains(SeatPairs.PartnerOf(s, seats)?.Id ?? 0)))
                        throw new ArgumentException("SWEETBOX seats must include both seats of the pair.");
                    var proposal = new ChatBookingProposal(movie.Id, id, movie.Title, session.StartTime, ids,
                        ids.Select(seatId => SeatPairs.Label(selected.Single(s => s.Id == seatId))).ToArray(),
                        selected.Sum(s => SeatPrices.For(session.Price, s.SeatType, session.Format)), DateTimeOffset.UtcNow.AddMinutes(5));
                    return (new { proposal, state = "REVIEW_REQUIRED", message = "No booking exists yet. Use the review button and explicitly confirm to hold seats; then complete payment yourself." }, proposal);
                }
        }
    }

    private async Task<JsonElement> ReadAccountAsync(string path, string accessToken, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        using var response = await clients.CreateClient("cinema-account").SendAsync(request, ct);
        if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            return JsonSerializer.SerializeToElement(new { error = "SIGN_IN_REQUIRED", message = "Account access denied. Sign in again." });
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<JsonElement>(ct);
    }

    private static long Id(JsonElement args, string key) => args.GetProperty(key).TryGetInt64(out var id) && id > 0
        ? id : throw new ArgumentException("Invalid id.");
    private static int Page(JsonElement args) => args.GetProperty("page").TryGetInt32(out var page) && page is >= 1 and <= 10000
        ? page : throw new ArgumentException("Invalid page.");
    private static string Text(JsonElement args, string key) => args.GetProperty(key).ValueKind == JsonValueKind.String && args.GetProperty(key).GetString() is { Length: <= 100 } text
        ? text.Trim() : throw new ArgumentException("Search text must be at most 100 characters.");
    private static (DateOnly? From, DateOnly? To) Dates(JsonElement args)
    {
        DateOnly? Read(string key) => args.GetProperty(key).ValueKind == JsonValueKind.Null ? null :
            args.GetProperty(key).ValueKind == JsonValueKind.String && DateOnly.TryParseExact(args.GetProperty(key).GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var date) && date != DateOnly.MaxValue
                ? date : throw new ArgumentException("Dates must be YYYY-MM-DD or null.");
        var from = Read("from");
        var to = Read("to");
        if (from > to) throw new ArgumentException("Start date must be before end date.");
        return (from, to);
    }
}
