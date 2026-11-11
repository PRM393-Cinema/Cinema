using System.Globalization;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace MovieService.Chat;

public sealed partial class CinemaChatTools
{
    internal const string CinemaTimeZone = "Asia/Ho_Chi_Minh";
    private const string CinemaName = "CosmoQ Cinema";
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);
    private static readonly string[] AgeRatings = ["P", "K", "T13", "T16", "T18"];
    internal static DateTime LocalNow => TimeZoneInfo.ConvertTimeBySystemTimeZoneId(DateTimeOffset.UtcNow, CinemaTimeZone).DateTime;

    internal sealed record ShowtimeOption(long Id, long MovieId, string Title, DateTime StartTime,
        string Room, string Format, int AvailableSeats)
    {
        public string DetailUrl => "/movies/" + MovieId;
        public string SeatUrl => $"/showtimes/{Id}/seats";
    }

    internal sealed record ShowtimeOptions(string Cinema, string TimeZone, DateTime From, DateTime ToExclusive,
        IReadOnlyList<ShowtimeOption> Items, string? Note = null, int Tickets = 1);

    private sealed record Occupancy(long ShowtimeId, int OccupiedSeats);
    private sealed record Rating(long MovieId, double Average, int Count);
    private sealed record Trend(long ShowtimeId, int RecentBookings, int RecentTickets, int PreviousBookings, int PreviousTickets);

    private IQueryable<Models.Movie> NowShowing(DateTime now)
    {
        var today = DateOnly.FromDateTime(now);
        return movies.Movies.AsNoTracking().Where(movie => movie.Status == "ACTIVE" &&
            (movie.ReleaseDate == null || movie.ReleaseDate <= today));
    }

    private async Task<ShowtimeOptions> FindCinemaShowtimesAsync(JsonElement args, DateTime now, CancellationToken ct)
    {
        var (from, to) = Dates(args);
        var start = from?.ToDateTime(TimeOnly.MinValue) ?? now;
        if (start < now) start = now;
        var end = to?.AddDays(1).ToDateTime(TimeOnly.MinValue) ?? start.AddDays(7);
        if (end <= start)
            return new(CinemaName, CinemaTimeZone, start, end, [], "The requested date range has passed.");
        if (end - start > TimeSpan.FromDays(7)) throw new ArgumentException("Search at most 7 days at a time.");

        var cinema = Text(args, "cinema");
        if (cinema.Length > 0 && !CinemaName.Contains(cinema, StringComparison.OrdinalIgnoreCase))
            return new(CinemaName, CinemaTimeZone, start, end, [], "The catalogue only covers CosmoQ Cinema.");
        var room = Text(args, "room").ToLowerInvariant();
        var genre = Text(args, "genre").ToLowerInvariant();
        var movieIds = args.GetProperty("movieIds").EnumerateArray().Select(item => item.GetInt64()).ToArray();
        if (movieIds.Length > 30 || movieIds.Any(id => id <= 0))
            throw new ArgumentException("Provide at most 30 positive movie IDs.");
        var tickets = args.GetProperty("tickets").GetInt32();
        if (tickets is < 1 or > 8) throw new ArgumentException("Choose 1 to 8 tickets.");
        var time = args.GetProperty("around").GetString();
        TimeOnly? around = null;
        if (time != null)
        {
            if (!TimeOnly.TryParseExact(time, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
                throw new ArgumentException("Use HH:mm for the requested time.");
            around = parsed;
        }

        var films = movies.Movies.AsNoTracking().Where(movie => movie.Status == "ACTIVE");
        if (movieIds.Length > 0) films = films.Where(movie => movieIds.Contains(movie.Id));
        if (genre.Length > 0) films = films.Where(movie => movie.Genre != null && movie.Genre.ToLower().Contains(genre));
        var titles = await films.ToDictionaryAsync(movie => movie.Id, movie => movie.Title, ct);
        if (titles.Count == 0) return new(CinemaName, CinemaTimeZone, start, end, []);

        var filmIds = titles.Keys.ToArray();
        var sessions = showtimes.Showtimes.AsNoTracking().Where(s => filmIds.Contains(s.MovieId) &&
            s.Status == "OPEN" && s.StartTime >= start && s.StartTime > now && s.StartTime < end);
        if (room.Length > 0) sessions = sessions.Where(s => s.Room.Name.ToLower().Contains(room));
        var upcoming = await sessions.OrderBy(s => s.StartTime).ThenBy(s => s.Id)
            .Select(s => new { s.Id, s.MovieId, s.StartTime, Room = s.Room.Name, s.Format, Capacity = s.Room.Seats.Count })
            .Where(s => s.Capacity >= tickets).ToListAsync(ct);
        if (around is { } requested)
            upcoming = upcoming
                .Select(s => new { Session = s, Minutes = Math.Abs((s.StartTime.TimeOfDay - requested.ToTimeSpan()).TotalMinutes) })
                .Where(s => s.Minutes <= 90).OrderBy(s => s.Minutes).Select(s => s.Session).ToList();

        var results = new List<ShowtimeOption>(5);
        foreach (var batch in upcoming.Chunk(100))
        {
            var query = string.Join("&", batch.Select(s => $"showtimeIds={s.Id}"));
            var occupancy = (await ReadInsightsAsync<Occupancy>("availability?" + query, ct)).ToDictionary(row => row.ShowtimeId);
            foreach (var session in batch)
            {
                if (!occupancy.TryGetValue(session.Id, out var row))
                    throw new InvalidDataException("Missing occupancy for a requested showtime.");
                var available = session.Capacity - row.OccupiedSeats;
                if (available < tickets) continue;
                results.Add(new(session.Id, session.MovieId, titles[session.MovieId], session.StartTime,
                    session.Room, session.Format, available));
                if (results.Count == 5) break;
            }
            if (results.Count == 5) break;
        }
        return new(CinemaName, CinemaTimeZone, start, end, results, Tickets: tickets);
    }

    private async Task<object> GetTopRatedMoviesAsync(DateTime now, CancellationToken ct)
    {
        var titles = await NowShowing(now).ToDictionaryAsync(movie => movie.Id, movie => movie.Title, ct);
        var ratings = (await ReadInsightsAsync<Rating>("ratings", ct)).Where(row => titles.ContainsKey(row.MovieId)).ToArray();
        if (ratings.Length == 0) return new { items = Array.Empty<object>() };

        // Ten neutral reviews keep small samples from dominating.
        const int priorCount = 10;
        const double neutralRating = 3;
        var items = ratings
            .Select(row => new { Row = row, Score = (row.Average * row.Count + neutralRating * priorCount) / (row.Count + priorCount) })
            .OrderByDescending(item => item.Score).ThenByDescending(item => item.Row.Count).ThenBy(item => item.Row.MovieId)
            .Take(5)
            .Select(item => new
            {
                Title = titles[item.Row.MovieId],
                DetailUrl = "/movies/" + item.Row.MovieId,
                AverageRating = Math.Round(item.Row.Average, 2),
                ReviewCount = item.Row.Count,
                AdjustedScore = Math.Round(item.Score, 3)
            });
        return new { scale = 5, items };
    }

    private async Task<object> GetTrendingMoviesAsync(CancellationToken ct)
    {
        var trends = await ReadInsightsAsync<Trend>("trends", ct);
        var ids = trends.Select(row => row.ShowtimeId).ToArray();
        var movieByShowtime = await showtimes.Showtimes.AsNoTracking().Where(s => ids.Contains(s.Id))
            .ToDictionaryAsync(s => s.Id, s => s.MovieId, ct);
        var movieIds = movieByShowtime.Values.Distinct().ToArray();
        var titles = await movies.Movies.AsNoTracking().Where(movie => movieIds.Contains(movie.Id) && movie.Status == "ACTIVE")
            .ToDictionaryAsync(movie => movie.Id, movie => movie.Title, ct);
        var items = trends.Where(row => movieByShowtime.ContainsKey(row.ShowtimeId))
            .GroupBy(row => movieByShowtime[row.ShowtimeId])
            .Where(group => titles.ContainsKey(group.Key))
            .Select(group => new
            {
                Id = group.Key,
                Title = titles[group.Key],
                DetailUrl = "/movies/" + group.Key,
                Tickets = group.Sum(row => row.RecentTickets),
                Bookings = group.Sum(row => row.RecentBookings),
                PreviousTickets = group.Sum(row => row.PreviousTickets),
                PreviousBookings = group.Sum(row => row.PreviousBookings)
            })
            .Where(movie => movie.Tickets > 0)
            .OrderByDescending(movie => movie.Tickets).ThenByDescending(movie => movie.Bookings)
            .ThenByDescending(movie => movie.Tickets - movie.PreviousTickets).ThenBy(movie => movie.Id)
            .Take(5)
            .Select(movie => new
            {
                movie.Title, movie.DetailUrl, movie.Tickets, movie.Bookings, movie.PreviousTickets, movie.PreviousBookings,
                TicketGrowth = movie.Tickets - movie.PreviousTickets,
                TicketGrowthPercent = movie.PreviousTickets == 0 ? (double?)null :
                    Math.Round(100.0 * (movie.Tickets - movie.PreviousTickets) / movie.PreviousTickets, 1)
            });
        return new { windowDays = 7, interestDataAvailable = false, items };
    }

    private async Task<object> GetMovieCandidatesAsync(JsonElement args, DateTime now, CancellationToken ct)
    {
        var genre = Text(args, "genre").ToLowerInvariant();
        var age = args.GetProperty("maxAgeRating").GetString();
        var ageIndex = age == null ? AgeRatings.Length - 1 : Array.IndexOf(AgeRatings, age);
        if (ageIndex < 0) throw new ArgumentException("Use a cinema age rating: P, K, T13, T16 or T18.");
        var min = Duration("minMinutes", 1);
        var max = Duration("maxMinutes", 600);
        if (min > max) throw new ArgumentException("Minimum duration must not exceed maximum duration.");
        var films = NowShowing(now).Where(movie => movie.DurationMinutes >= min && movie.DurationMinutes <= max);
        if (age != null)
        {
            var allowed = AgeRatings[..(ageIndex + 1)];
            films = films.Where(movie => allowed.Contains(movie.AgeRating));
        }
        if (genre.Length > 0) films = films.Where(movie => movie.Genre != null && movie.Genre.ToLower().Contains(genre));
        var count = await films.CountAsync(ct);
        var items = await films.OrderByDescending(movie => movie.ReleaseDate).ThenBy(movie => movie.Id).Take(30)
            .Select(movie => new
            {
                movie.Id, movie.Title, movie.Genre, movie.AgeRating, movie.DurationMinutes,
                DetailUrl = "/movies/" + movie.Id,
                Description = movie.Description == null ? null : movie.Description.Substring(0, Math.Min(movie.Description.Length, 1000))
            }).ToListAsync(ct);
        return new { count, contentAdvisoriesAvailable = false, items };

        int Duration(string key, int fallback)
        {
            var value = args.GetProperty(key);
            if (value.ValueKind == JsonValueKind.Null) return fallback;
            if (!value.TryGetInt32(out var duration) || duration is < 1 or > 600)
                throw new ArgumentException("Use a duration from 1 to 600 minutes.");
            return duration;
        }
    }

    private async Task<T[]> ReadInsightsAsync<T>(string path, CancellationToken ct)
    {
        var response = await ReadCinemaAsync("api/v1/cinema-insights/" + path, null, ct);
        return response.Deserialize<T[]>(WebJson) ?? throw new InvalidDataException("Missing cinema insights.");
    }
}
