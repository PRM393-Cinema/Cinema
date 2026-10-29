using BookingService.Clients.Interfaces;
using BookingService.Data;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Models;
using BookingService.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Services.Implementations
{
    public class MovieReviewService : IMovieReviewService
    {
        private const int MaxPageSize = 50;

        private readonly BookingDbContext _context;
        private readonly IShowtimeClient _showtimeClient;

        public MovieReviewService(BookingDbContext context, IShowtimeClient showtimeClient)
        {
            _context = context;
            _showtimeClient = showtimeClient;
        }

        public async Task<MovieReviewsResponse> GetForMovieAsync(long movieId, long? viewerId, int page, int size)
        {
            page = Math.Max(page, 1);
            size = size <= 0 ? 10 : Math.Min(size, MaxPageSize);
            var query = _context.MovieReviews.AsNoTracking().Where(r => r.MovieId == movieId);

            var counts = await query
                .GroupBy(r => r.Rating)
                .Select(g => new { Rating = g.Key, Count = g.Count() })
                .ToListAsync();
            var stars = new int[5];
            foreach (var row in counts.Where(row => row.Rating is >= 1 and <= 5))
            {
                stars[row.Rating - 1] = row.Count;
            }

            var total = stars.Sum();
            var items = await query
                .OrderByDescending(r => r.UpdatedAt)
                .ThenByDescending(r => r.Id)
                .Skip((page - 1) * size)
                .Take(size)
                .ToListAsync();

            return new MovieReviewsResponse
            {
                MovieId = movieId,
                Count = total,
                Average = total == 0
                    ? 0
                    : Math.Round(stars.Select((count, index) => count * (index + 1)).Sum() / (double)total, 1),
                Stars = stars,
                Reviews = new PagedResult<MovieReviewResponse>
                {
                    Items = items.Select(r => ToResponse(r, viewerId)).ToList(),
                    PageNumber = page,
                    PageSize = size,
                    TotalCount = total,
                    TotalPages = (int)Math.Ceiling(total / (double)size)
                }
            };
        }

        public async Task<List<MovieReviewResponse>> GetMineAsync(long userId)
        {
            var rows = await (
                from review in _context.MovieReviews.AsNoTracking()
                join booking in _context.Bookings.AsNoTracking()
                    on review.BookingId equals booking.Id into bookings
                from booking in bookings.DefaultIfEmpty()
                where review.UserId == userId
                orderby review.UpdatedAt descending, review.Id descending
                select new { Review = review, MovieTitle = booking == null ? null : booking.MovieTitle }
            ).ToListAsync();
            return rows.Select(row =>
            {
                var response = ToResponse(row.Review, userId);
                response.MovieTitle = row.MovieTitle;
                return response;
            }).ToList();
        }

        public async Task<BookingReviewResponse> GetForBookingAsync(long userId, long bookingId)
        {
            var booking = await OwnBookingAsync(userId, bookingId);
            var movieId = (await _showtimeClient.GetShowtimeAsync(booking.ShowtimeId)).MovieId;
            var review = await _context.MovieReviews.AsNoTracking()
                .FirstOrDefaultAsync(r => r.UserId == userId && r.MovieId == movieId);

            return new BookingReviewResponse
            {
                BookingId = bookingId,
                MovieId = movieId,
                CanReview = booking.CheckedInAt != null,
                Review = review == null ? null : ToResponse(review, userId)
            };
        }

        public async Task<MovieReviewResponse> SaveAsync(long userId, string reviewerName, MovieReviewRequest request)
        {
            var booking = await OwnBookingAsync(userId, request.BookingId!.Value);

            if (booking.CheckedInAt == null)
            {
                throw new BusinessException("You can review a movie after you have watched it (your ticket was checked in).");
            }

            var movieId = (await _showtimeClient.GetShowtimeAsync(booking.ShowtimeId)).MovieId;
            var now = DateTime.Now;
            var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();

            var review = await _context.MovieReviews
                .FirstOrDefaultAsync(r => r.UserId == userId && r.MovieId == movieId);
            if (review == null)
            {
                review = new MovieReview { UserId = userId, MovieId = movieId, CreatedAt = now };
                _context.MovieReviews.Add(review);
            }

            review.BookingId = booking.Id;
            review.ReviewerName = reviewerName;
            review.Rating = (short)request.Rating!.Value;
            review.Comment = comment;
            review.UpdatedAt = now;
            await _context.SaveChangesAsync();
            return ToResponse(review, userId);
        }

        public async Task<bool> DeleteAsync(long id, long userId, bool admin)
        {
            var review = await _context.MovieReviews.FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException($"Review {id} was not found.");
            if (!admin && review.UserId != userId)
            {
                return false;
            }

            _context.MovieReviews.Remove(review);
            await _context.SaveChangesAsync();
            return true;
        }

        // Vé của người khác coi như không có (404), không để lộ vé tồn tại
        private async Task<Booking> OwnBookingAsync(long userId, long bookingId)
        {
            var booking = await _context.Bookings.AsNoTracking().FirstOrDefaultAsync(b => b.Id == bookingId);
            return booking != null && booking.UserId == userId
                ? booking
                : throw new NotFoundException($"Booking {bookingId} was not found.");
        }

        // Tên hiện trên đánh giá: họ tên trong token, không có thì email đã che bớt (khach***@gmail.com)
        public static string DisplayName(string? fullName, string? email)
        {
            if (!string.IsNullOrWhiteSpace(fullName))
            {
                return fullName.Trim().Length > 150 ? fullName.Trim()[..150] : fullName.Trim();
            }

            if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            {
                return "Khách hàng";
            }

            var at = email.IndexOf('@');
            var name = email[..at];
            return (name.Length <= 3 ? name[..1] : name[..3]) + "***" + email[at..];
        }

        private static MovieReviewResponse ToResponse(MovieReview review, long? viewerId)
        {
            return new MovieReviewResponse
            {
                Id = review.Id,
                MovieId = review.MovieId,
                BookingId = review.BookingId,
                ReviewerName = review.ReviewerName,
                Rating = review.Rating,
                Comment = review.Comment,
                CreatedAt = review.CreatedAt,
                UpdatedAt = review.UpdatedAt,
                Mine = viewerId == review.UserId
            };
        }
    }
}
