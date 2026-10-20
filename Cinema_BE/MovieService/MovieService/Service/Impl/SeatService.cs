using MovieService.Exception;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Extensions;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;
using ShowtimeService.Service.Interface;

namespace ShowtimeService.Service.Impl
{
    public class SeatService : ISeatService
    {
        private readonly ISeatRepository _seatRepository;
        private readonly IRoomRepository _roomRepository;
        private readonly IShowtimeRepository _showtimeRepository;

        public SeatService(
            ISeatRepository seatRepository,
            IRoomRepository roomRepository,
            IShowtimeRepository showtimeRepository)
        {
            _seatRepository = seatRepository;
            _roomRepository = roomRepository;
            _showtimeRepository = showtimeRepository;
        }

        public async Task<List<SeatResponse>> GetSeatsByRoomAsync(long roomId)
        {
            if (roomId <= 0)
            {
                throw new BusinessException("Room ID must be greater than 0.");
            }

            var room = await _roomRepository.GetRoomByIdAsync(roomId);

            if (room == null)
            {
                throw new NotFoundException(
                    $"Room with ID {roomId} was not found.");
            }

            var seats = await _seatRepository.GetAllSeatsByRoomAsync(roomId);

            return seats.Select(s => s.ToResponse()).ToList();
        }

        public async Task<SeatResponse?> GetSeatByIdAsync(long seatId)
        {
            if (seatId <= 0)
            {
                throw new BusinessException("Seat ID must be greater than 0.");
            }

            var seat = await _seatRepository.GetSeatByIdAsync(seatId);

            if (seat == null)
            {
                throw new NotFoundException(
                    $"Seat with ID {seatId} was not found.");
            }

            return seat.ToResponse();
        }

        public async Task<PagedResult<SeatResponse>> GenerateSeatAsync(
            GenerateSeatRequest request)
        {
            if (request == null)
            {
                throw new BusinessException(
                    "Generate seat request is required.");
            }

            if (request.RoomId <= 0)
            {
                throw new BusinessException(
                    "Room ID must be greater than 0.");
            }

            if (request.Rows <= 0)
            {
                throw new BusinessException(
                    "Rows must be greater than 0.");
            }

            if (request.SeatsPerRow <= 0)
            {
                throw new BusinessException(
                    "Seats per row must be greater than 0.");
            }

            var room = await _roomRepository.GetRoomByIdAsync(
                request.RoomId);

            if (room == null)
            {
                throw new NotFoundException(
                    $"Room with ID {request.RoomId} was not found.");
            }

            var hasShowtimes = await _showtimeRepository
                .ExistsByRoomIdAsync(request.RoomId);

            if (hasShowtimes)
            {
                throw new BusinessException(
                    "Cannot regenerate seats because the room has associated showtimes.");
            }

            // Generating again would add a second A1..; change seats one by one instead.
            if ((await _seatRepository.GetAllSeatsByRoomAsync(request.RoomId)).Count > 0)
            {
                throw new BusinessException(
                    "The room already has seats.");
            }

            var seats = await _seatRepository.GenerateSeatsAsync(
                request.RoomId,
                request.Rows,
                request.SeatsPerRow);

            return seats.ToPagedResult();
        }

        public async Task<SeatResponse?> UpdateSeatTypeAsync(
            long seatId,
            UpdateSeatTypeRequest request)
        {
            if (seatId <= 0)
            {
                throw new BusinessException(
                    "Seat ID must be greater than 0.");
            }

            if (request == null)
            {
                throw new BusinessException(
                    "Update seat request is required.");
            }

            if (string.IsNullOrWhiteSpace(request.SeatType))
            {
                throw new BusinessException(
                    "Seat type is required.");
            }

            var seat = await _seatRepository.GetSeatByIdAsync(seatId);

            if (seat == null)
            {
                throw new NotFoundException(
                    $"Seat with ID {seatId} was not found.");
            }

            var hasShowtimes = await _showtimeRepository
                .ExistsByRoomIdAsync(seat.RoomId);

            if (hasShowtimes)
            {
                throw new BusinessException(
                    "Cannot update seat type because the room has associated showtimes.");
            }

            // Sweetbox là ghế đôi: đổi một ghế thì ghế cặp đổi theo
            var type = request.SeatType.Trim().ToUpperInvariant();
            var partner = SeatPairs.PartnerOf(
                seat,
                await _seatRepository.GetAllSeatsByRoomAsync(seat.RoomId));
            var newTypes = new Dictionary<long, string> { [seat.Id] = type };

            if (SeatPairs.IsSweetbox(type))
            {
                if (partner == null)
                {
                    throw new BusinessException(
                        $"Seat {SeatPairs.Label(seat)} has no seat " +
                        $"{seat.SeatRow}{SeatPairs.PartnerNumber(seat.SeatNumber)} to pair with: " +
                        "sweetbox seats come in pairs.");
                }

                newTypes[partner.Id] = type;
            }
            else if (partner != null &&
                SeatPairs.IsSweetbox(seat.SeatType) &&
                SeatPairs.IsSweetbox(partner.SeatType))
            {
                newTypes[partner.Id] = type;
            }

            await _seatRepository.ChangeRoomSeatsAsync(seat.RoomId, [], [], newTypes);

            return (await _seatRepository.GetSeatByIdAsync(seatId))?.ToResponse();
        }

        public async Task<bool> DeleteSeatAsync(long seatId)
        {
            if (seatId <= 0)
            {
                throw new BusinessException(
                    "Seat ID must be greater than 0.");
            }

            var seat = await _seatRepository.GetSeatByIdAsync(seatId);

            if (seat == null)
            {
                throw new NotFoundException(
                    $"Seat with ID {seatId} was not found.");
            }

            var hasShowtimes = await _showtimeRepository
                .ExistsByRoomIdAsync(seat.RoomId);

            if (hasShowtimes)
            {
                throw new BusinessException(
                    "Cannot delete seat because the room has associated showtimes.");
            }

            // Bỏ một ghế sweetbox thì ghế cặp còn lại thành ghế thường
            var partner = SeatPairs.IsSweetbox(seat.SeatType)
                ? SeatPairs.PartnerOf(seat, await _seatRepository.GetAllSeatsByRoomAsync(seat.RoomId))
                : null;
            var newTypes = partner != null && SeatPairs.IsSweetbox(partner.SeatType)
                ? new Dictionary<long, string> { [partner.Id] = SeatPairs.Normal }
                : null;

            await _seatRepository.ChangeRoomSeatsAsync(seat.RoomId, [], [seatId], newTypes);
            return true;
        }

        // Đổi số ghế của phòng mà không đánh số lại ghế cũ: ghế mới lấp đầy hàng cuối rồi
        // sang hàng kế tiếp (tối đa hàng Z), bớt ghế thì bỏ từ ghế cuối sơ đồ trở lên
        public async Task<List<SeatResponse>> UpdateRoomSeatsAsync(
            long roomId,
            UpdateRoomSeatsRequest request)
        {
            if (roomId <= 0)
            {
                throw new BusinessException("Room ID must be greater than 0.");
            }

            if (request == null)
            {
                throw new BusinessException("Update room seats request is required.");
            }

            var room = await _roomRepository.GetRoomByIdAsync(roomId);

            if (room == null)
            {
                throw new NotFoundException(
                    $"Room with ID {roomId} was not found.");
            }

            if (await _showtimeRepository.ExistsByRoomIdAsync(roomId))
            {
                throw new BusinessException(
                    "Cannot change seats because the room has associated showtimes.");
            }

            var seats = await _seatRepository.GetAllSeatsByRoomAsync(roomId);
            var change = request.TotalSeats - seats.Count;
            List<Seat> removed = change < 0 ? seats.TakeLast(-change).ToList() : [];
            var added = new List<Seat>();

            if (change > 0)
            {
                var seatsPerRow = request.SeatsPerRow
                    ?? (seats.Count > 0
                        ? seats.GroupBy(s => s.SeatRow).Max(row => row.Count())
                        : throw new BusinessException(
                            "Seats per row is required for a room without seats."));
                var seatType = string.IsNullOrWhiteSpace(request.SeatType)
                    ? SeatPairs.Normal
                    : request.SeatType.Trim().ToUpperInvariant();

                added = PlanAddedSeats(roomId, seats, change, seatsPerRow, seatType);
            }

            if (change != 0)
            {
                // Ghế sweetbox mất ghế cặp (ghế cặp bị bỏ, hay ghế mới lẻ đôi) thành ghế thường
                var unpaired = SeatPairs.Unpaired(seats.Except(removed).Concat(added).ToList());
                foreach (var seat in unpaired.Intersect(added))
                {
                    seat.SeatType = SeatPairs.Normal;
                }

                await _seatRepository.ChangeRoomSeatsAsync(
                    roomId,
                    added,
                    removed.Select(s => s.Id).ToList(),
                    unpaired.Except(added).ToDictionary(s => s.Id, _ => SeatPairs.Normal));
            }

            var updated = await _seatRepository.GetAllSeatsByRoomAsync(roomId);
            return updated.Select(s => s.ToResponse()).ToList();
        }

        // seats đã sắp theo hàng rồi số ghế
        private static List<Seat> PlanAddedSeats(
            long roomId,
            IReadOnlyList<Seat> seats,
            int count,
            int seatsPerRow,
            string seatType)
        {
            var lastRow = seats.Count > 0 ? seats[^1].SeatRow : null;
            var inRow = lastRow == null ? 0 : seats.Count(s => s.SeatRow == lastRow);
            var next = lastRow == null
                ? 1
                : seats.Where(s => s.SeatRow == lastRow).Max(s => s.SeatNumber) + 1;

            var added = new List<Seat>();
            while (added.Count < count)
            {
                if (lastRow == null || inRow >= seatsPerRow)
                {
                    lastRow = NextRow(lastRow);
                    inRow = 0;
                    next = 1;
                }

                added.Add(new Seat
                {
                    RoomId = roomId,
                    SeatRow = lastRow,
                    SeatNumber = next++,
                    SeatType = seatType
                });
                inRow++;
            }

            return added;
        }

        private static string NextRow(string? row)
        {
            if (row == null)
            {
                return "A";
            }

            if (row.Length == 1 && row[0] >= 'A' && row[0] < 'Z')
            {
                return ((char)(row[0] + 1)).ToString();
            }

            throw new BusinessException(
                "Not enough rows: a room has rows A to Z. Use more seats per row.");
        }
    }
}
