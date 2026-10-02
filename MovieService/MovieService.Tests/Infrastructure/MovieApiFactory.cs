using System.Net.Http.Headers;
using MovieService.Data;
using MovieService.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using ShowtimeService.Data;
using ShowtimeService.Models;
using Testcontainers.PostgreSql;

namespace MovieService.Tests.Infrastructure;

// MovieService chạy trong bộ nhớ với PostgreSQL thật (container); có sẵn 1 phim, 2 phòng chiếu
public class MovieApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder("postgres:17-alpine").Build();
    private int _nextDay;

    public long MovieId { get; private set; }

    public long RoomId { get; private set; }

    public List<long> SeatIds { get; } = new();

    public long OtherRoomSeatId { get; private set; }

    public static string StaffToken => TestJwt.Create(201, "nhanvien@test.local", "ROLE_STAFF");

    public static string CustomerToken => TestJwt.Create(101, "khach@test.local", "ROLE_CUSTOMER");

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        await using (var movies = new MovieDbContext(Options<MovieDbContext>("cinema_movie_test")))
        {
            await movies.Database.EnsureCreatedAsync();

            var movie = new Movie
            {
                Title = "Phim Kiểm Thử",
                DurationMinutes = 110,
                Status = "ACTIVE",
                CreatedAt = DateTime.Now
            };

            movies.Movies.Add(movie);
            await movies.SaveChangesAsync();
            MovieId = movie.Id;
        }

        await using (var showtimes = new ShowtimeDbContext(Options<ShowtimeDbContext>("cinema_showtime_test")))
        {
            await showtimes.Database.EnsureCreatedAsync();

            var room = new Room { Name = "Phòng Test", TotalSeats = 5 };
            var otherRoom = new Room { Name = "Phòng Khác", TotalSeats = 1 };
            showtimes.Rooms.AddRange(room, otherRoom);
            await showtimes.SaveChangesAsync();

            var seats = Enumerable.Range(1, 5)
                .Select(number => new Seat { RoomId = room.Id, SeatRow = "A", SeatNumber = number, SeatType = "NORMAL" })
                .ToList();
            var otherSeat = new Seat { RoomId = otherRoom.Id, SeatRow = "A", SeatNumber = 1, SeatType = "NORMAL" };

            showtimes.Seats.AddRange(seats);
            showtimes.Seats.Add(otherSeat);
            await showtimes.SaveChangesAsync();

            RoomId = room.Id;
            SeatIds.AddRange(seats.Select(seat => seat.Id));
            OtherRoomSeatId = otherSeat.Id;
        }
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();
        await _postgres.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("Logging:LogLevel:Default", "Warning");
        builder.UseSetting("Logging:LogLevel:Microsoft.EntityFrameworkCore", "Warning");
        builder.UseSetting("ConnectionStrings:MovieDb", ConnectionString("cinema_movie_test"));
        builder.UseSetting("ConnectionStrings:ShowtimeDb", ConnectionString("cinema_showtime_test"));
        builder.UseSetting("Jwt:SecretKey", TestJwt.SecretKey);
        builder.UseSetting("RabbitMq:Enabled", "false");
    }

    public HttpClient ClientFor(string? token)
    {
        var client = CreateClient();

        if (token != null)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return client;
    }

    // Mỗi test xếp suất chiếu vào một ngày riêng để không trùng lịch phòng với test khác
    public DateTime NextFreeDay()
    {
        return DateTime.Today.AddDays(30 + Interlocked.Increment(ref _nextDay)).AddHours(9);
    }

    public async Task<T> QueryAsync<T>(Func<ShowtimeDbContext, Task<T>> query)
    {
        using var scope = Services.CreateScope();
        return await query(scope.ServiceProvider.GetRequiredService<ShowtimeDbContext>());
    }

    private DbContextOptions<TContext> Options<TContext>(string database) where TContext : DbContext
    {
        return new DbContextOptionsBuilder<TContext>().UseNpgsql(ConnectionString(database)).Options;
    }

    private string ConnectionString(string database)
    {
        return new NpgsqlConnectionStringBuilder(_postgres.GetConnectionString())
        {
            Database = database
        }.ConnectionString;
    }
}

[CollectionDefinition(Name)]
public sealed class MovieApiCollection : ICollectionFixture<MovieApiFactory>
{
    public const string Name = "movie-api";
}
