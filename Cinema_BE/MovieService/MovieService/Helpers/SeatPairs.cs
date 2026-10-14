using ShowtimeService.Models;

namespace MovieService.Helpers
{
    // Sweetbox là ghế đôi: ghế số lẻ ghép với ghế chẵn bên phải (1-2, 3-4, ...) trong cùng hàng
    public static class SeatPairs
    {
        public const string Sweetbox = "SWEETBOX";
        public const string Normal = "NORMAL";

        public static bool IsSweetbox(string? seatType) =>
            string.Equals(seatType?.Trim(), Sweetbox, StringComparison.OrdinalIgnoreCase);

        public static int PartnerNumber(int seatNumber) =>
            seatNumber % 2 == 1 ? seatNumber + 1 : seatNumber - 1;

        public static string Label(Seat seat) => $"{seat.SeatRow}{seat.SeatNumber}";

        public static Seat? PartnerOf(Seat seat, IEnumerable<Seat> seats)
        {
            var number = PartnerNumber(seat.SeatNumber);
            return seats.FirstOrDefault(s => s.SeatRow == seat.SeatRow && s.SeatNumber == number);
        }

        // Ghế sweetbox mà ghế cặp không còn hoặc không còn là sweetbox
        public static List<Seat> Unpaired(IReadOnlyCollection<Seat> seats) =>
            seats
                .Where(seat => IsSweetbox(seat.SeatType) &&
                    !IsSweetbox(PartnerOf(seat, seats)?.SeatType))
                .ToList();
    }
}
