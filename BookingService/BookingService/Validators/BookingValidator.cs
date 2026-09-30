using BookingService.DTOs.Requests;

namespace BookingService.Validators
{
    public class BookingValidator
    {
        public static void ValidateCreateBooking(BookingRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (request.UserId == null || request.UserId <= 0)
            {
                throw new ArgumentException("User id is required.");
            }

            if (request.ShowtimeId == null || request.ShowtimeId <= 0)
            {
                throw new ArgumentException("Showtime id is required.");
            }

            if (request.Seats == null || request.Seats.Count == 0)
            {
                throw new ArgumentException(
                    "At least one seat must be selected.");
            }

            var duplicateSeatIds = request.Seats
                .GroupBy(x => x.SeatId)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key)
                .ToList();

            if (duplicateSeatIds.Count > 0)
            {
                throw new ArgumentException(
                    "The same seat cannot be selected multiple times.");
            }

            foreach (var seat in request.Seats)
            {
                if (seat.SeatId <= 0)
                {
                    throw new ArgumentException(
                        "Seat id is required.");
                }
            }
        }
    }
}
