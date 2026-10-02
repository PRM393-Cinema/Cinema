using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Mapping
{
    public static class BookingMapping
    {
        public static BookingResponse ToResponse(
        this Booking booking,
        List<BookingSeatResponse>? seats = null)
        {
            return new BookingResponse
            {
                Id = booking.Id,
                BookingCode = booking.BookingCode,
                UserId = booking.UserId,
                CustomerEmail = booking.CustomerEmail,
                ShowtimeId = booking.ShowtimeId,
                Status = booking.Status,
                TotalAmount = booking.TotalAmount,
                PaymentId = booking.PaymentId,
                MovieTitle = booking.MovieTitle,
                ShowTime = booking.ShowTime,
                ExpiresAt = booking.ExpiresAt,
                CreatedAt = booking.CreatedAt,
                Seats = seats ?? new List<BookingSeatResponse>()
            };
        }

        public static BookingSeatResponse ToResponse(
            this BookingSeat bookingSeat)
        {
            return new BookingSeatResponse
            {
                Id = bookingSeat.Id,
                SeatId = bookingSeat.SeatId,
                SeatLabel = bookingSeat.SeatLabel,
                Price = bookingSeat.Price
            };
        }
    }
}
