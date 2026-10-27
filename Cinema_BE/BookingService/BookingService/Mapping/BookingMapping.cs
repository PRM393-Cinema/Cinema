using BookingService.DTOs.Responses;
using BookingService.Models;

namespace BookingService.Mapping
{
    public static class BookingMapping
    {
        public static BookingResponse ToResponse(
        this Booking booking,
        List<BookingSeatResponse>? seats = null,
        IEnumerable<BookingConcession>? concessionLines = null)
        {
            var concessions = (concessionLines ?? booking.Concessions)
                .OrderBy(item => item.Id)
                .Select(item => new BookingConcessionResponse
                {
                    ItemId = item.ItemId,
                    Name = item.ItemName,
                    UnitPrice = item.UnitPrice,
                    Quantity = item.Quantity,
                    Amount = item.UnitPrice * item.Quantity
                })
                .ToList();

            return new BookingResponse
            {
                Id = booking.Id,
                BookingCode = booking.BookingCode,
                UserId = booking.UserId,
                CustomerEmail = booking.CustomerEmail,
                CustomerPhone = booking.CustomerPhone,
                ShowtimeId = booking.ShowtimeId,
                Status = booking.Status,
                TotalAmount = booking.TotalAmount,
                PaymentId = booking.PaymentId,
                MovieTitle = booking.MovieTitle,
                ShowTime = booking.ShowTime,
                ExpiresAt = booking.ExpiresAt,
                CheckedInAt = booking.CheckedInAt,
                CreatedAt = booking.CreatedAt,
                Seats = seats ?? new List<BookingSeatResponse>(),
                ConcessionsAmount = booking.ConcessionsAmount,
                Concessions = concessions
            };
        }

        public static ConcessionItemResponse ToResponse(this ConcessionItem item)
        {
            return new ConcessionItemResponse
            {
                Id = item.Id,
                Name = item.Name,
                Description = item.Description,
                Price = item.Price,
                ImageUrl = item.ImageUrl,
                Active = item.Active,
                SortOrder = item.SortOrder
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
