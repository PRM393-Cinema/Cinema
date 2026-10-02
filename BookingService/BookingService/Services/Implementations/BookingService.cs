using BookingService.Configuration;
using BookingService.Data;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Messaging;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;
using BookingService.Validators;
using BookingService.Clients.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace BookingService.Services.Implementations
{
    public class BookingService : IBookingService
    {
        // Thời gian giữ ghế chờ thanh toán
        private static readonly TimeSpan HoldDuration = TimeSpan.FromMinutes(10);

        private readonly BookingDbContext _context;
        private readonly IBookingRepository _bookingRepository;
        private readonly IBookingSeatRepository _bookingSeatRepository;
        private readonly ISeatReservationRepository _seatReservationRepository;
        private readonly IShowtimeClient _showtimeClient;
        private readonly OutboxWriter<BookingDbContext> _outbox;
        private readonly RefundPolicyOptions _refundPolicy;
        private readonly ILogger<BookingService> _logger;

        public BookingService(
            BookingDbContext context,
            IBookingRepository bookingRepository,
            IBookingSeatRepository bookingSeatRepository,
            ISeatReservationRepository seatReservationRepository,
            IShowtimeClient showtimeClient,
            OutboxWriter<BookingDbContext> outbox,
            IOptions<RefundPolicyOptions> refundPolicy,
            ILogger<BookingService> logger)
        {
            _context = context;
            _bookingRepository = bookingRepository;
            _bookingSeatRepository = bookingSeatRepository;
            _seatReservationRepository = seatReservationRepository;
            _showtimeClient = showtimeClient;
            _outbox = outbox;
            _refundPolicy = refundPolicy.Value;
            _logger = logger;
        }

        public async Task<PagedResult<BookingResponse>> GetAllBookingsAsync(
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var bookings = await _bookingRepository.GetAllAsync(
                page,
                size,
                sortBy,
                sortDir);

            return await ToPagedResultAsync(bookings);
        }

        public async Task<PagedResult<BookingResponse>> GetBookingsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var bookings = await _bookingRepository.GetBookingByUserIdAsync(
                userId,
                page,
                size,
                sortBy,
                sortDir);

            return await ToPagedResultAsync(bookings);
        }

        public async Task<PagedResult<BookingResponse>> GetBookingsByStatusAsync(
            string status,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            if (string.IsNullOrWhiteSpace(status))
            {
                throw new ArgumentException("Status is required.");
            }

            var bookings = await _bookingRepository.GetBookingByStatusAsync(
                status,
                page,
                size,
                sortBy,
                sortDir);

            return await ToPagedResultAsync(bookings);
        }

        public async Task<PagedResult<BookingResponse>> GetBookingsByDateRangeAsync(
            DateTime start,
            DateTime end,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            if (start > end)
            {
                throw new ArgumentException(
                    "Start date must be before or equal to end date.");
            }

            var bookings = await _bookingRepository.GetBookingByDateRangeAsync(
                start,
                end,
                page,
                size,
                sortBy,
                sortDir);

            return await ToPagedResultAsync(bookings);
        }

        public async Task<BookingResponse> GetBookingByIdAsync(long id)
        {
            var booking = await _bookingRepository.GetBookingByIdAsync(id);

            if (booking == null)
            {
                throw new KeyNotFoundException(
                    $"Booking with id {id} was not found.");
            }

            return await MapBookingAsync(booking);
        }

        public async Task<BookingResponse> CreateBookingAsync(BookingRequest request)
        {
            BookingValidator.ValidateCreateBooking(request);

            var showtimeId = request.ShowtimeId!.Value;
            var userId = request.UserId!.Value;

            var seatIds = request.Seats
                .Select(x => x.SeatId)
                .Distinct()
                .ToList();

            if (seatIds.Count != request.Seats.Count)
            {
                throw new BusinessException(
                    "Duplicate seats are not allowed.");
            }

            // Get authoritative seat information before opening transaction.
            // MovieService cũng kiểm tra suất chiếu còn mở bán và chưa bắt đầu.
            var seatInfos =
                await _showtimeClient.GetSeatsAsync(
                    showtimeId,
                    seatIds);

            if (seatInfos.Count != seatIds.Count)
            {
                throw new BusinessException(
                    "One or more seats are invalid.");
            }

            // Giờ chiếu và tên phim lấy từ MovieService, không tin dữ liệu app gửi lên
            // (giờ chiếu được dùng cho chính sách huỷ vé).
            var showtime = await _showtimeClient.GetShowtimeAsync(showtimeId);
            var movieTitle =
                await _showtimeClient.GetMovieTitleAsync(showtime.MovieId) ??
                request.MovieTitle;

            var seatMap = seatInfos.ToDictionary(
                x => x.SeatId);

            var totalAmount = seatIds.Sum(
                seatId => seatMap[seatId].Price);

            var expiresAt =
                DateTime.Now.Add(HoldDuration);

            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                // Khóa (FOR UPDATE) các dòng giữ chỗ đã có của những ghế được chọn.
                // Ghế chưa từng được giữ ở suất chiếu này thì chưa có dòng nào -> coi là còn trống.
                var existingReservations = new Dictionary<long, SeatReservation>();

                foreach (var seatId in seatIds)
                {
                    var reservation =
                        await _seatReservationRepository
                            .GetByShowtimeIdAndSeatIdForUpdateAsync(
                                showtimeId,
                                seatId);

                    if (reservation == null)
                    {
                        continue;
                    }

                    var status = reservation.Status
                        .Trim()
                        .ToUpperInvariant();

                    if (status == "BOOKED")
                    {
                        throw new ConflictException(
                            $"Seat {seatMap[seatId].SeatLabel} is already booked.");
                    }

                    if (status == "HELD" &&
                        reservation.HeldUntil.HasValue &&
                        reservation.HeldUntil.Value > DateTime.Now)
                    {
                        throw new ConflictException(
                            $"Seat {seatMap[seatId].SeatLabel} is currently held by another booking.");
                    }

                    existingReservations[seatId] = reservation;
                }

                var booking = new Booking
                {
                    UserId = userId,
                    CustomerEmail = string.IsNullOrWhiteSpace(request.CustomerEmail)
                        ? null
                        : request.CustomerEmail.Trim(),
                    ShowtimeId = showtimeId,
                    Status = "PENDING",
                    TotalAmount = totalAmount,
                    BookingCode = GenerateBookingCode(),
                    MovieTitle = movieTitle,
                    ShowTime = showtime.StartTime,
                    CreatedAt = DateTime.Now,
                    ExpiresAt = expiresAt
                };

                booking =
                    await _bookingRepository
                        .CreateBookingAsync(booking);

                var bookingSeats = new List<BookingSeat>();

                foreach (var seatId in seatIds)
                {
                    var seatInfo = seatMap[seatId];

                    var bookingSeat = new BookingSeat
                    {
                        BookingId = booking.Id,
                        SeatId = seatId,
                        SeatLabel = seatInfo.SeatLabel,
                        Price = seatInfo.Price
                    };

                    await _bookingSeatRepository
                        .AddAsync(bookingSeat);

                    bookingSeats.Add(bookingSeat);

                    if (existingReservations.TryGetValue(seatId, out var reservation))
                    {
                        reservation.Status = "HELD";
                        reservation.HeldUntil = expiresAt;
                        reservation.BookingId = booking.Id;

                        await _seatReservationRepository
                            .UpdateAsync(reservation);
                    }
                    else
                    {
                        // Unique constraint uq_seat_per_showtime chặn trường hợp
                        // hai booking cùng giữ một ghế mới tại cùng thời điểm.
                        await _seatReservationRepository
                            .AddAsync(new SeatReservation
                            {
                                ShowtimeId = showtimeId,
                                SeatId = seatId,
                                Status = "HELD",
                                HeldUntil = expiresAt,
                                BookingId = booking.Id
                            });
                    }
                }

                _outbox.Add(
                    EventTypes.BookingCreated,
                    EventFactory.Booking(booking, bookingSeats));

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                return await MapBookingAsync(booking);
            }
            catch (DbUpdateException ex) when (IsUniqueViolation(ex))
            {
                await transaction.RollbackAsync();

                throw new ConflictException(
                    "One or more selected seats were just taken by another booking. Please choose again.");
            }
            catch
            {
                // Lỗi xảy ra sau khi đã commit (CurrentTransaction = null) thì không rollback nữa,
                // để giữ nguyên lỗi gốc thay vì lỗi "This NpgsqlTransaction has completed".
                if (_context.Database.CurrentTransaction is not null)
                {
                    await transaction.RollbackAsync();
                }

                throw;
            }
        }

        // Staff/Admin xác nhận tay tại quầy (vd: khách trả tiền mặt).
        // Không truyền email thì gửi vé về email lưu trên booking.
        public async Task<BookingResponse> ConfirmBookingAsync(
            long id,
            string paymentMethod,
            string? recipientEmail)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                var booking = await GetBookingForUpdateAsync(id);

                if (NormalizeStatus(booking) != "PENDING")
                {
                    throw new ConflictException(
                        "Only PENDING bookings can be confirmed.");
                }

                // Quá thời gian giữ chỗ: chuyển EXPIRED, nhả ghế (lưu lại trước khi báo lỗi)
                if (booking.ExpiresAt.HasValue &&
                    booking.ExpiresAt.Value <= DateTime.Now)
                {
                    var releasedSeats = await ReleaseSeatsAsync(booking, "EXPIRED", includeBooked: false);
                    booking.Status = "EXPIRED";

                    _outbox.Add(
                        EventTypes.BookingExpired,
                        EventFactory.Booking(booking, releasedSeats, previousStatus: "PENDING"));

                    await _bookingRepository.UpdateBookingAsync(
                        booking.Id,
                        booking);

                    await transaction.CommitAsync();

                    throw new ConflictException(
                        "Booking has expired.");
                }

                var seats =
                    await _bookingSeatRepository
                        .GetByBookingIdAsync(booking.Id);

                var reservations = await LockReservationsAsync(booking, seats);

                var lost = reservations.FirstOrDefault(
                    x => !IsHeldBy(x.Reservation, booking.Id));

                if (lost.Seat != null)
                {
                    throw new ConflictException(lost.Reservation == null
                        ? $"Reservation for seat {lost.Seat.SeatLabel} was not found."
                        : $"Seat {lost.Seat.SeatLabel} is not held by this booking.");
                }

                await MarkConfirmedAsync(booking, seats, reservations, recipientEmail);

                await transaction.CommitAsync();

                return booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList());
            }
            catch
            {
                // Lỗi xảy ra sau khi đã commit (CurrentTransaction = null) thì không rollback nữa,
                // để giữ nguyên lỗi gốc thay vì lỗi "This NpgsqlTransaction has completed".
                if (_context.Database.CurrentTransaction is not null)
                {
                    await transaction.RollbackAsync();
                }

                throw;
            }
        }

        // Hệ thống tự xác nhận sau khi PayOS báo đã thanh toán (khách không tự xác nhận được).
        // Gọi lại nhiều lần vẫn an toàn (webhook gửi lại, app bấm xác minh lại).
        // Tiền về sau khi booking đã hết hạn: vẫn xác nhận nếu các ghế chưa bị booking khác lấy.
        public async Task<BookingResponse> ConfirmPaidBookingAsync(
            long id,
            string? recipientEmail)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                var booking = await GetBookingForUpdateAsync(id);
                var status = NormalizeStatus(booking);

                var seats =
                    await _bookingSeatRepository
                        .GetByBookingIdAsync(booking.Id);

                if (status == "CONFIRMED")
                {
                    await transaction.CommitAsync();

                    return booking.ToResponse(
                        seats.Select(x => x.ToResponse()).ToList());
                }

                if (status is not ("PENDING" or "EXPIRED"))
                {
                    throw new ConflictException(
                        $"Payment succeeded but booking {booking.BookingCode} is {status} and cannot be confirmed.");
                }

                var reservations = await LockReservationsAsync(booking, seats);
                var now = DateTime.Now;

                // Ghế mất = đang thuộc booking khác (đã bán, hoặc đang được giữ còn hạn)
                var lost = reservations.FirstOrDefault(x =>
                    x.Reservation != null &&
                    !IsHeldBy(x.Reservation, booking.Id) &&
                    IsOccupied(x.Reservation, now));

                if (lost.Seat != null)
                {
                    // Nhả các ghế còn giữ, chuyển booking sang EXPIRED; tiền đã trả được hoàn (phía payment xử lý)
                    if (status == "PENDING")
                    {
                        await ReleaseSeatsAsync(booking, "EXPIRED", includeBooked: false);
                        booking.Status = "EXPIRED";

                        _outbox.Add(
                            EventTypes.BookingExpired,
                            EventFactory.Booking(
                                booking,
                                seats,
                                previousStatus: "PENDING",
                                reason: $"ghế {lost.Seat.SeatLabel} đã có người khác đặt"));

                        await _bookingRepository.UpdateBookingAsync(
                            booking.Id,
                            booking);
                    }

                    await transaction.CommitAsync();

                    throw new ConflictException(
                        $"Payment succeeded but seat {lost.Seat.SeatLabel} is no longer available for booking {booking.BookingCode}.");
                }

                await MarkConfirmedAsync(booking, seats, reservations, recipientEmail);

                await transaction.CommitAsync();

                return booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList());
            }
            catch (DbUpdateException ex) when (IsUniqueViolation(ex))
            {
                await transaction.RollbackAsync();

                throw new ConflictException(
                    "Payment succeeded but one or more seats were just taken by another booking.");
            }
            catch
            {
                if (_context.Database.CurrentTransaction is not null)
                {
                    await transaction.RollbackAsync();
                }

                throw;
            }
        }

        // Khách: huỷ booking chưa thanh toán; booking đã thanh toán chỉ huỷ được khi còn đủ thời gian
        // trước giờ chiếu (RefundPolicy:CustomerCancelBeforeHours). Staff/Admin huỷ được mọi lúc.
        // Booking đã thanh toán bị huỷ: phía payment nhận booking.cancelled và tạo yêu cầu hoàn 100%.
        public async Task<BookingResponse> CancelBookingAsync(
            long id,
            bool manager,
            string? reason = null)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                var booking = await GetBookingForUpdateAsync(id);
                var status = NormalizeStatus(booking);

                if (status == "CANCELLED")
                {
                    throw new ConflictException(
                        "Booking has already been cancelled.");
                }

                if (status == "EXPIRED")
                {
                    throw new ConflictException(
                        "Expired booking cannot be cancelled.");
                }

                if (!manager && status == "CONFIRMED")
                {
                    EnsureCustomerCanCancelPaidBooking(booking);
                }
                else if (!manager && status != "PENDING")
                {
                    throw new ConflictException(
                        "This booking cannot be cancelled.");
                }

                var seats = await CancelLockedBookingAsync(
                    booking,
                    reason,
                    manager ? "STAFF" : "CUSTOMER");

                await transaction.CommitAsync();

                return booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList());
            }
            catch
            {
                // Lỗi xảy ra sau khi đã commit (CurrentTransaction = null) thì không rollback nữa,
                // để giữ nguyên lỗi gốc thay vì lỗi "This NpgsqlTransaction has completed".
                if (_context.Database.CurrentTransaction is not null)
                {
                    await transaction.RollbackAsync();
                }

                throw;
            }
        }

        // Khách bấm huỷ trên trang PayOS: huỷ booking đang chờ thanh toán để nhả ghế ngay.
        // Booking không còn PENDING thì bỏ qua.
        public async Task CancelUnpaidBookingAsync(long id)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            var booking =
                await _bookingRepository
                    .GetBookingByIdForUpdateAsync(id);

            if (booking == null || NormalizeStatus(booking) != "PENDING")
            {
                await transaction.CommitAsync();
                return;
            }

            await CancelLockedBookingAsync(booking, "Khách huỷ thanh toán", "CUSTOMER");

            await transaction.CommitAsync();
        }

        // Suất chiếu bị huỷ (event showtime.cancelled): huỷ mọi booking PENDING / CONFIRMED của suất đó.
        // Gọi lại vẫn an toàn vì booking đã huỷ thì bỏ qua.
        public async Task<int> CancelBookingsOfShowtimeAsync(long showtimeId, string reason)
        {
            var bookingIds =
                await _bookingRepository
                    .GetActiveBookingIdsByShowtimeAsync(showtimeId);

            var cancelled = 0;

            foreach (var id in bookingIds)
            {
                await using var transaction =
                    await _context.Database.BeginTransactionAsync();

                var booking =
                    await _bookingRepository
                        .GetBookingByIdForUpdateAsync(id);

                if (booking == null ||
                    NormalizeStatus(booking) is not ("PENDING" or "CONFIRMED"))
                {
                    await transaction.CommitAsync();
                    continue;
                }

                await CancelLockedBookingAsync(booking, reason, "SYSTEM");

                await transaction.CommitAsync();
                cancelled++;
            }

            return cancelled;
        }

        // Job chạy nền gọi định kỳ: booking PENDING quá hạn giữ ghế -> EXPIRED, nhả ghế.
        // Mỗi booking một transaction ngắn; booking vừa được thanh toán / huỷ trong lúc đó thì bỏ qua.
        public async Task<List<BookingResponse>> ExpireOverdueBookingsAsync(
            int batchSize)
        {
            var overdueIds =
                await _bookingRepository
                    .GetOverduePendingBookingIdsAsync(
                        DateTime.Now,
                        batchSize);

            var expired = new List<BookingResponse>();

            foreach (var id in overdueIds)
            {
                await using var transaction =
                    await _context.Database.BeginTransactionAsync();

                var booking =
                    await _bookingRepository
                        .GetBookingByIdForUpdateAsync(id);

                if (booking == null ||
                    NormalizeStatus(booking) != "PENDING" ||
                    booking.ExpiresAt is not { } expiresAt ||
                    expiresAt > DateTime.Now)
                {
                    await transaction.CommitAsync();
                    continue;
                }

                var seats = await ReleaseSeatsAsync(booking, "EXPIRED", includeBooked: false);

                booking.Status = "EXPIRED";

                _outbox.Add(
                    EventTypes.BookingExpired,
                    EventFactory.Booking(booking, seats, previousStatus: "PENDING"));

                await _bookingRepository.UpdateBookingAsync(
                    booking.Id,
                    booking);

                await transaction.CommitAsync();

                expired.Add(booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList()));
            }

            return expired;
        }

        public async Task<List<long>> GetOccupiedSeatIdsAsync(
            long showtimeId)
        {
            return await _bookingRepository
                .GetOccupiedSeatIdsAsync(showtimeId, DateTime.Now);
        }

        private void EnsureCustomerCanCancelPaidBooking(Booking booking)
        {
            var hours = _refundPolicy.CustomerCancelBeforeHours;

            if (!booking.ShowTime.HasValue ||
                booking.ShowTime.Value - DateTime.Now < TimeSpan.FromHours(hours))
            {
                throw new ConflictException(
                    $"Paid bookings can only be cancelled at least {hours} hours before the showtime. Please contact the cinema.");
            }
        }

        // Huỷ booking đã khoá: nhả ghế (cả ghế đã bán), CANCELLED, ghi event booking.cancelled
        private async Task<List<BookingSeat>> CancelLockedBookingAsync(
            Booking booking,
            string? reason,
            string cancelledBy)
        {
            var previousStatus = NormalizeStatus(booking);

            var seats = await ReleaseSeatsAsync(booking, "AVAILABLE", includeBooked: true);

            booking.Status = "CANCELLED";
            booking.ExpiresAt = null;

            _outbox.Add(
                EventTypes.BookingCancelled,
                EventFactory.Booking(
                    booking,
                    seats,
                    previousStatus,
                    string.IsNullOrWhiteSpace(reason) ? null : reason.Trim(),
                    cancelledBy));

            await _bookingRepository.UpdateBookingAsync(
                booking.Id,
                booking);

            return seats;
        }

        private async Task<Booking> GetBookingForUpdateAsync(long id)
        {
            var booking =
                await _bookingRepository
                    .GetBookingByIdForUpdateAsync(id);

            if (booking == null)
            {
                throw new KeyNotFoundException(
                    $"Booking with id {id} was not found.");
            }

            return booking;
        }

        private async Task<List<(BookingSeat Seat, SeatReservation? Reservation)>> LockReservationsAsync(
            Booking booking,
            IEnumerable<BookingSeat> seats)
        {
            var reservations = new List<(BookingSeat Seat, SeatReservation? Reservation)>();

            foreach (var seat in seats)
            {
                var reservation =
                    await _seatReservationRepository
                        .GetByShowtimeIdAndSeatIdForUpdateAsync(
                            booking.ShowtimeId,
                            seat.SeatId);

                reservations.Add((seat, reservation));
            }

            return reservations;
        }

        // Chốt ghế: BOOKED cho booking này (ghế chưa có dòng giữ chỗ thì tạo mới), booking -> CONFIRMED,
        // ghi event booking.confirmed (Notification gửi email vé sau khi commit)
        private async Task MarkConfirmedAsync(
            Booking booking,
            List<BookingSeat> seats,
            List<(BookingSeat Seat, SeatReservation? Reservation)> reservations,
            string? recipientEmail)
        {
            var previousStatus = NormalizeStatus(booking);

            foreach (var (seat, reservation) in reservations)
            {
                if (reservation == null)
                {
                    await _seatReservationRepository
                        .AddAsync(new SeatReservation
                        {
                            ShowtimeId = booking.ShowtimeId,
                            SeatId = seat.SeatId,
                            Status = "BOOKED",
                            BookingId = booking.Id
                        });

                    continue;
                }

                reservation.Status = "BOOKED";
                reservation.HeldUntil = null;
                reservation.BookingId = booking.Id;

                await _seatReservationRepository
                    .UpdateAsync(reservation);
            }

            booking.Status = "CONFIRMED";
            booking.ExpiresAt = null;

            _outbox.Add(
                EventTypes.BookingConfirmed,
                EventFactory.Booking(
                    booking,
                    seats,
                    previousStatus,
                    recipientEmail: string.IsNullOrWhiteSpace(recipientEmail) ? null : recipientEmail.Trim()));

            await _bookingRepository.UpdateBookingAsync(
                booking.Id,
                booking);
        }

        // Nhả các ghế đang thuộc booking (HELD, và cả BOOKED nếu includeBooked) để booking khác đặt được
        private async Task<List<BookingSeat>> ReleaseSeatsAsync(
            Booking booking,
            string releasedStatus,
            bool includeBooked)
        {
            var seats =
                await _bookingSeatRepository
                    .GetByBookingIdAsync(booking.Id);

            foreach (var seat in seats)
            {
                var reservation =
                    await _seatReservationRepository
                        .GetByShowtimeIdAndSeatIdForUpdateAsync(
                            booking.ShowtimeId,
                            seat.SeatId);

                if (reservation == null ||
                    reservation.BookingId != booking.Id)
                {
                    continue;
                }

                if (reservation.Status == "HELD" ||
                    (includeBooked && reservation.Status == "BOOKED"))
                {
                    reservation.Status = releasedStatus;
                    reservation.HeldUntil = null;
                    reservation.BookingId = null;

                    await _seatReservationRepository
                        .UpdateAsync(reservation);
                }
            }

            return seats;
        }

        private static string NormalizeStatus(Booking booking)
        {
            return booking.Status
                .Trim()
                .ToUpperInvariant();
        }

        private static bool IsHeldBy(SeatReservation? reservation, long bookingId)
        {
            return reservation is { Status: "HELD" } &&
                   reservation.BookingId == bookingId;
        }

        private static bool IsOccupied(SeatReservation reservation, DateTime now)
        {
            return reservation.Status == "BOOKED" ||
                   (reservation.Status == "HELD" &&
                    reservation.HeldUntil.HasValue &&
                    reservation.HeldUntil.Value > now);
        }

        private static bool IsUniqueViolation(DbUpdateException ex)
        {
            return ex.InnerException is PostgresException
            {
                SqlState: PostgresErrorCodes.UniqueViolation
            };
        }

        private async Task<BookingResponse> MapBookingAsync(
            Booking booking)
        {
            var seats = await _bookingSeatRepository
                .GetByBookingIdAsync(booking.Id);

            return booking.ToResponse(
                seats.Select(x => x.ToResponse()).ToList());
        }

        private async Task<PagedResult<BookingResponse>> ToPagedResultAsync(
            PagedList<Booking> pagedBookings)
        {
            var responses = new List<BookingResponse>();

            foreach (var booking in pagedBookings)
            {
                responses.Add(
                    await MapBookingAsync(booking));
            }

            return new PagedResult<BookingResponse>
            {
                Items = responses,
                PageNumber = pagedBookings.PageNumber,
                PageSize = pagedBookings.PageSize,
                TotalPages = pagedBookings.TotalPages,
                TotalCount = pagedBookings.TotalCount
            };
        }

        private static string GenerateBookingCode()
        {
            return $"BK-{DateTime.Now:yyyyMMddHHmmss}-{Random.Shared.Next(100000, 999999)}";
        }
    }
}
