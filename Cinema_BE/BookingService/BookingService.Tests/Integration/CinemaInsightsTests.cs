using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Data;
using BookingService.Models;
using BookingService.Tests.Infrastructure;

namespace BookingService.Tests.Integration;

public sealed class CinemaInsightsTests(BookingApiFactory factory) : IClassFixture<BookingApiFactory>
{
    [Fact]
    public async Task GuestAggregates_UseConfirmedSalesWindowsAndOnlyCurrentOccupancy()
    {
        const long showtimeId = 802410;
        const long movieId = 802411;
        var now = DateTime.Now;
        await factory.ExecuteAsync<BookingDbContext>(async db =>
        {
            db.Bookings.AddRange(
                Booking("RECENT", "CONFIRMED", now.AddDays(-1), null, 1, 2),
                Booking("PREVIOUS", "CONFIRMED", now.AddDays(-8), null, 3),
                Booking("OLD", "CONFIRMED", now.AddDays(-15), null, 4),
                Booking("REFUND", "REFUND_PENDING", now.AddDays(-1), null, 5),
                Booking("HOLD", "PENDING", now.AddMinutes(-1), now.AddMinutes(4), 6),
                Booking("EXPIRED", "PENDING", now.AddMinutes(-15), now.AddMinutes(-10), 7),
                Booking("CANCELLED", "CANCELLED", now.AddDays(-1), null, 8));
            db.MovieReviews.AddRange(
                new MovieReview { MovieId = movieId, UserId = 1, BookingId = 1, ReviewerName = "QA", Rating = 5 },
                new MovieReview { MovieId = movieId, UserId = 2, BookingId = 2, ReviewerName = "QA", Rating = 4 });
            await db.SaveChangesAsync();
        });

        using var guest = factory.CreateClient();
        var availability = await guest.GetFromJsonAsync<JsonElement>($"/api/v1/cinema-insights/availability?showtimeIds={showtimeId}&showtimeIds=802412");
        Assert.Equal(6, availability[0].GetProperty("occupiedSeats").GetInt32());
        Assert.Equal(0, availability[1].GetProperty("occupiedSeats").GetInt32());

        var ratings = await guest.GetFromJsonAsync<JsonElement>("/api/v1/cinema-insights/ratings");
        var rating = Assert.Single(ratings.EnumerateArray(), row => row.GetProperty("movieId").GetInt64() == movieId);
        Assert.Equal(4.5, rating.GetProperty("average").GetDouble());
        Assert.Equal(2, rating.GetProperty("count").GetInt32());

        var trends = await guest.GetFromJsonAsync<JsonElement>("/api/v1/cinema-insights/trends");
        var trend = Assert.Single(trends.EnumerateArray(), row => row.GetProperty("showtimeId").GetInt64() == showtimeId);
        Assert.Equal(1, trend.GetProperty("recentBookings").GetInt32());
        Assert.Equal(2, trend.GetProperty("recentTickets").GetInt32());
        Assert.Equal(1, trend.GetProperty("previousBookings").GetInt32());
        Assert.Equal(1, trend.GetProperty("previousTickets").GetInt32());

        Booking Booking(string label, string status, DateTime created, DateTime? expires, params long[] seats) => new()
        {
            BookingCode = "QA-INSIGHTS-" + label,
            ShowtimeId = showtimeId,
            Status = status,
            CreatedAt = created,
            ExpiresAt = expires,
            BookingSeats = seats.Select(id => new BookingSeat { SeatId = id, SeatLabel = "A" + id, Price = 100000 }).ToList()
        };
    }
}
