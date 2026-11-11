using BookingService.Data;
using BookingService.Repositories.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Controllers;

[ApiController, AllowAnonymous, Route("api/v1/cinema-insights")]
public sealed class CinemaInsightsController(BookingDbContext db, IBookingRepository bookings) : ControllerBase
{
    [HttpGet("availability")]
    public async Task<IActionResult> Availability([FromQuery] long[] showtimeIds, CancellationToken cancellationToken)
    {
        if (showtimeIds.Length is < 1 or > 100 || showtimeIds.Any(id => id <= 0))
            return BadRequest("Provide 1 to 100 positive showtime IDs.");

        var counts = await bookings.CountOccupiedSeatsAsync(showtimeIds, DateTime.Now, cancellationToken);
        return Ok(showtimeIds.Distinct().Select(id => new { ShowtimeId = id, OccupiedSeats = counts.GetValueOrDefault(id) }));
    }

    [HttpGet("ratings")]
    public async Task<IActionResult> Ratings(CancellationToken cancellationToken) =>
        Ok(await db.MovieReviews.AsNoTracking().GroupBy(review => review.MovieId)
            .Select(group => new
            {
                MovieId = group.Key,
                Average = group.Average(review => (double)review.Rating),
                Count = group.Count()
            })
            .ToListAsync(cancellationToken));

    [HttpGet("trends")]
    public async Task<IActionResult> Trends(CancellationToken cancellationToken)
    {
        var now = DateTime.Now;
        var recent = now.AddDays(-7);
        var previous = now.AddDays(-14);
        return Ok(await db.Bookings.AsNoTracking()
            .Where(booking => booking.Status == "CONFIRMED" && booking.CreatedAt >= previous && booking.CreatedAt <= now)
            .GroupBy(booking => booking.ShowtimeId)
            .Select(group => new
            {
                ShowtimeId = group.Key,
                RecentBookings = group.Count(booking => booking.CreatedAt >= recent),
                RecentTickets = group.Sum(booking => booking.CreatedAt >= recent ? booking.BookingSeats.Count : 0),
                PreviousBookings = group.Count(booking => booking.CreatedAt < recent),
                PreviousTickets = group.Sum(booking => booking.CreatedAt < recent ? booking.BookingSeats.Count : 0)
            })
            .ToListAsync(cancellationToken));
    }
}
