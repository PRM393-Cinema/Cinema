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

            // Không có user id: vé khách vãng lai (chỉ Staff/Admin, controller điền user id cho khách)
            if (request.UserId is <= 0)
            {
                throw new ArgumentException("User id must be greater than 0.");
            }

            if (request.Concessions.Count > 10)
            {
                throw new ArgumentException("At most 10 different snack items per booking.");
            }

            if (request.Concessions.Any(item => item.Quantity is < 1 or > 20))
            {
                throw new ArgumentException("Snack quantity must be between 1 and 20.");
            }

            if (request.Concessions.Select(item => item.ItemId).Distinct().Count() != request.Concessions.Count)
            {
                throw new ArgumentException("Each snack item can be listed only once.");
            }

            if (!string.IsNullOrWhiteSpace(request.CustomerPhone) &&
                !System.Text.RegularExpressions.Regex.IsMatch(request.CustomerPhone.Trim(), @"^\+?[0-9 .-]{8,19}$"))
            {
                throw new ArgumentException("Customer phone must be 8 to 15 digits.");
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
