using ShowtimeService.DTOs.Request;
using ShowtimeService.DTOs.Response;
using ShowtimeService.Exception;
using ShowtimeService.Extensions;
using MovieService.Helpers;
using ShowtimeService.Models;
using ShowtimeService.Repository.Interface;
using ShowtimeService.Service.Interface;
using MovieService.Exception;

namespace ShowtimeService.Service.Impl
{
    public class RoomService : IRoomService
    {
        private readonly IRoomRepository _roomRepository;
        private readonly ISeatRepository _seatRepository;
        private readonly IShowtimeRepository _showtimeRepository;
        private readonly IUnitOfWork _unitOfWork;

        public RoomService(IRoomRepository roomRepository, ISeatRepository seatRepository, IShowtimeRepository showtimeRepository, IUnitOfWork unitOfWork)
        {
            _roomRepository = roomRepository;
            _seatRepository = seatRepository;
            _showtimeRepository = showtimeRepository;
            _unitOfWork = unitOfWork;
        }

        public async Task<PagedResult<RoomResponse>> GetAllRoomsAsync(int pageNumber, int pageSize, string sortBy, string sortDir)
        {
            var p = PaginationUtils.Normalize(pageNumber, pageSize, sortBy, sortDir);
            var result = await _roomRepository.GetAllRoomsAsync(pageNumber, pageSize, sortBy, sortDir);
            return result.ToPagedResult();
        }

        public async Task<RoomResponse?> GetRoomByIdAsync(long roomId)
        {
            var room = await _roomRepository.GetRoomByIdAsync(roomId);
            if (room == null)
            {
                throw new NotFoundException($"Room with ID {roomId} was not found.");
            }

            return room?.ToResponse();
        }

        public async Task<RoomResponse> CreateRoomAsync(RoomRequest request)
        {
            if (request == null)
            {
                throw new BadRequestException("Room request cannot be null.");
            }

            if (string.IsNullOrWhiteSpace(request.Name))
            {
                throw new BadRequestException("Room name is required.");
            }

            if (request.Rows <= 0 || request.SeatsPerRow <= 0)
            {
                throw new BadRequestException(
                    "Rows and seats per row must be greater than 0.");
            }

            if (await _roomRepository.ExistRoomAsync(request.Name))
            {
                throw new BadRequestException(
                    $"Room with name '{request.Name}' already exists.");
            }

            var room = new Room
            {
                Name = request.Name,
                TotalSeats = request.Rows * request.SeatsPerRow
            };

            var createdRoom = await _roomRepository.CreateRoomAsync(room);

            return room.ToResponse();
        }
        
        public async Task<RoomResponse?> UpdateRoomAsync(long roomId, RoomRequest request)
        {
            if (request == null)
            {
                throw new BadRequestException("Room request cannot be null.");
            }

            var existingRoom = await _roomRepository.GetRoomByIdAsync(roomId);
            if (existingRoom == null)
            {
                throw new NotFoundException($"Room with ID {roomId} was not found.");
            }

            await _unitOfWork.BeginTransactionAsync();

            try
            {
                existingRoom.Name = request.Name;
                existingRoom.TotalSeats = request.Rows * request.SeatsPerRow;
                var updatedRoom = await _roomRepository.UpdateRoomAsync(roomId, existingRoom);
                await _unitOfWork.CommitTransactionAsync();
                return updatedRoom?.ToResponse();
            }
            catch
            {
                await _unitOfWork.RollbackTransactionAsync();
                throw;
            }
        }

        public async Task<bool> DeleteRoomAsync(long roomId)
        {
            var existingRoom = await _roomRepository.GetRoomByIdAsync(roomId);

            if (existingRoom == null)
            {
                throw new NotFoundException(
                    $"Room with ID {roomId} was not found.");
            }

            var showtimes = await _showtimeRepository
                .GetShowtimesByRoomIdAsync(roomId);

            if (showtimes.Any())
            {
                throw new BadRequestException(
                    $"Cannot delete room with ID {roomId} because it has associated showtimes.");
            }

            return await _roomRepository.DeleteRoomAsync(roomId);
        }

        public async Task<PagedResult<RoomResponse>> SearchRoomsAsync(
            string keyword,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            if (string.IsNullOrWhiteSpace(keyword))
            {
                throw new BusinessException("Search keyword is required.");
            }

            var p = PaginationUtils.Normalize(page, size, sortBy, sortDir);

            var rooms = await _roomRepository.SearchRoomsAsync(
                keyword.Trim(),
                p.PageNumber,
                p.PageSize,
                p.SortBy,
                p.SortDir);

            return rooms.ToPagedResult();
        }
    }
}
