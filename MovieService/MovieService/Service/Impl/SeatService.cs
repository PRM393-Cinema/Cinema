using MovieService.Exception;
using MovieService.Helpers;
using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Extensions;
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

            seat.SeatType = request.SeatType.Trim();

            var updatedSeat = await _seatRepository.UpdateSeatAsync(seatId, seat);

            return updatedSeat.ToResponse();
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

            return await _seatRepository.DeleteSeatAsync(seatId);
        }
    }
}
