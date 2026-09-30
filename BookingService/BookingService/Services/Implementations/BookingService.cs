using BookingService.Data;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;
using BookingService.Validators;
using BookingService.Clients.Interfaces;
using BookingService.DTOs;
using System.Text.Encodings.Web;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace BookingService.Services.Implementations
{
    public class BookingService : IBookingService
    {
        private readonly BookingDbContext _context;
        private readonly IBookingRepository _bookingRepository;
        private readonly IBookingSeatRepository _bookingSeatRepository;
        private readonly ISeatReservationRepository _seatReservationRepository;
        private readonly IShowtimeClient _showtimeClient;
        private readonly INotificationService _notificationService;
        private readonly ILogger<BookingService> _logger;

        public BookingService(
            BookingDbContext context,
            IBookingRepository bookingRepository,
            IBookingSeatRepository bookingSeatRepository,
            ISeatReservationRepository seatReservationRepository,
            IShowtimeClient showtimeClient,
            INotificationService notificationService,
            ILogger<BookingService> logger)
        {
            _context = context;
            _bookingRepository = bookingRepository;
            _bookingSeatRepository = bookingSeatRepository;
            _seatReservationRepository = seatReservationRepository;
            _showtimeClient = showtimeClient;
            _notificationService = notificationService;
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
                throw new InvalidOperationException(
                    "Duplicate seats are not allowed.");
            }

            // Get authoritative seat information before opening transaction.
            var seatInfos =
                await _showtimeClient.GetSeatsAsync(
                    showtimeId,
                    seatIds);

            if (seatInfos.Count != seatIds.Count)
            {
                throw new InvalidOperationException(
                    "One or more seats are invalid.");
            }

            var seatMap = seatInfos.ToDictionary(
                x => x.SeatId);

            var totalAmount = seatIds.Sum(
                seatId => seatMap[seatId].Price);

            var expiresAt =
                DateTime.Now.AddMinutes(10);

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
                        throw new InvalidOperationException(
                            $"Seat {seatId} is already booked.");
                    }

                    if (status == "HELD" &&
                        reservation.HeldUntil.HasValue &&
                        reservation.HeldUntil.Value > DateTime.Now)
                    {
                        throw new InvalidOperationException(
                            $"Seat {seatId} is currently held.");
                    }

                    existingReservations[seatId] = reservation;
                }

                var booking = new Booking
                {
                    UserId = userId,
                    ShowtimeId = showtimeId,
                    Status = "PENDING",
                    TotalAmount = totalAmount,
                    BookingCode = GenerateBookingCode(),
                    MovieTitle = request.MovieTitle,
                    ShowTime = request.ShowTime,
                    CreatedAt = DateTime.Now,
                    ExpiresAt = expiresAt
                };

                booking =
                    await _bookingRepository
                        .CreateBookingAsync(booking);

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

                await transaction.CommitAsync();

                return await MapBookingAsync(booking);
            }
            catch (DbUpdateException ex) when (
                ex.InnerException is PostgresException
                {
                    SqlState: PostgresErrorCodes.UniqueViolation
                })
            {
                await transaction.RollbackAsync();

                throw new InvalidOperationException(
                    "One or more selected seats were just taken by another booking. Please choose again.");
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<BookingResponse> ConfirmBookingAsync(
            long id,
            string paymentMethod,
            string recipientEmail)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                var booking =
                    await _bookingRepository
                        .GetBookingByIdForUpdateAsync(id);

                if (booking == null)
                {
                    throw new KeyNotFoundException(
                        $"Booking with id {id} was not found.");
                }

                if (!string.Equals(
                        booking.Status,
                        "PENDING",
                        StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(
                        "Only PENDING bookings can be confirmed.");
                }

                if (booking.ExpiresAt.HasValue &&
                    booking.ExpiresAt.Value <= DateTime.Now)
                {
                    booking.Status = "EXPIRED";

                    await _bookingRepository.UpdateBookingAsync(
                        booking.Id,
                        booking);

                    await transaction.CommitAsync();

                    throw new InvalidOperationException(
                        "Booking has expired.");
                }

                /*
                 * Payment should be processed before
                 * changing booking to CONFIRMED.
                 */

                booking.Status = "CONFIRMED";

                await _bookingRepository.UpdateBookingAsync(
                    booking.Id,
                    booking);

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

                    if (reservation == null)
                    {
                        throw new InvalidOperationException(
                            $"Reservation for seat {seat.SeatId} was not found.");
                    }

                    if (reservation.Status != "HELD" ||
                        reservation.BookingId != booking.Id)
                    {
                        throw new InvalidOperationException(
                            $"Seat {seat.SeatId} is not held by this booking.");
                    }

                    reservation.Status = "BOOKED";
                    reservation.HeldUntil = null;

                    await _seatReservationRepository
                        .UpdateAsync(reservation);
                }

                await transaction.CommitAsync();

                var response = booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList());

                // Notification is deliberately sent after the booking
                // transaction commits. Email/notification downtime must not
                // rollback a successful booking or payment transaction.
                try
                {
                    await _notificationService.SendNotificationFromEventAsync(
                        $"BOOKING_OK:{booking.Id}",
                        booking.UserId,
                        booking.Id,
                        "BOOKING_CONFIRMED",
                        BuildBookingConfirmationEmail(
                            booking,
                            seats,
                            recipientEmail));
                }
                catch (Exception exception)
                {
                    _logger.LogWarning(
                        exception,
                        "Booking {BookingId} was confirmed but confirmation email could not be sent.",
                        booking.Id);
                }

                return response;
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<BookingResponse> CancelBookingAsync(
            long id,
            bool manager)
        {
            await using var transaction =
                await _context.Database.BeginTransactionAsync();

            try
            {
                var booking =
                    await _bookingRepository
                        .GetBookingByIdForUpdateAsync(id);

                if (booking == null)
                {
                    throw new KeyNotFoundException(
                        $"Booking with id {id} was not found.");
                }

                var status = booking.Status
                    .Trim()
                    .ToUpperInvariant();

                if (status == "CANCELLED")
                {
                    throw new InvalidOperationException(
                        "Booking has already been cancelled.");
                }

                if (status == "EXPIRED")
                {
                    throw new InvalidOperationException(
                        "Expired booking cannot be cancelled.");
                }

                if (!manager && status != "PENDING")
                {
                    throw new InvalidOperationException(
                        "This booking cannot be cancelled.");
                }

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

                    if (reservation == null)
                    {
                        continue;
                    }

                    if (reservation.BookingId != booking.Id)
                    {
                        continue;
                    }

                    if (reservation.Status == "HELD")
                    {
                        reservation.Status = "EXPIRED";
                        reservation.HeldUntil = null;
                        reservation.BookingId = null;

                        await _seatReservationRepository
                            .UpdateAsync(reservation);
                    }
                }

                booking.Status = "CANCELLED";
                booking.ExpiresAt = null;

                await _bookingRepository.UpdateBookingAsync(
                    booking.Id,
                    booking);

                await transaction.CommitAsync();

                return booking.ToResponse(
                    seats.Select(x => x.ToResponse()).ToList());
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task ExpirePastShowtimeBookingsAsync()
        {
            /*
             * Ideally this query should be executed directly at repository
             * level instead of loading every booking into memory.
             *
             * The condition is:
             *
             * Status = PENDING
             * AND Showtime has already passed
             *
             * To implement this correctly, BookingService needs Showtime
             * information from ShowtimeService.
             */
            throw new NotImplementedException(
                "This operation requires ShowtimeService integration.");
        }

        public async Task<List<long>> GetOccupiedSeatIdsAsync(
            long showtimeId)
        {
            return await _bookingRepository
                .GetOccupiedSeatIdsAsync(showtimeId);
        }

        private async Task<Booking> GetBookingEntityAsync(long id)
        {
            var booking = await _bookingRepository.GetBookingByIdAsync(id);

            if (booking == null)
            {
                throw new KeyNotFoundException(
                    $"Booking with id {id} was not found.");
            }

            return booking;
        }

        private static EmailMessage BuildBookingConfirmationEmail(
            Booking booking,
            IEnumerable<BookingSeat> seats,
            string recipientEmail)
        {
            var encoder = HtmlEncoder.Default;
            var movieTitle = encoder.Encode(
                booking.MovieTitle ?? "Mobile Cinema");
            var bookingCode = encoder.Encode(booking.BookingCode);
            var showTime = booking.ShowTime?.ToString("dd/MM/yyyy HH:mm") ??
                "Chưa cập nhật";
            var seatList = string.Join(
                ", ",
                seats.Select(seat => encoder.Encode(seat.SeatLabel)));

            var content = $"""
                <html>
                  <body style="font-family:Arial,sans-serif;color:#202124;line-height:1.5">
                    <h2>Đặt vé thành công</h2>
                    <p>Đơn đặt vé <strong>{bookingCode}</strong> của bạn đã được xác nhận.</p>
                    <p><strong>Phim:</strong> {movieTitle}<br/>
                       <strong>Suất chiếu:</strong> {encoder.Encode(showTime)}<br/>
                       <strong>Ghế:</strong> {seatList}<br/>
                       <strong>Tổng tiền:</strong> {booking.TotalAmount:N0} VND</p>
                    <div style="background:#fff3cd;border:1px solid #ffecb5;padding:12px;margin:16px 0;color:#664d03">
                      <strong>ĐẶC BIỆT LƯU Ý:</strong> Vui lòng có mặt trước giờ chiếu ít nhất 15 phút và xuất trình mã đặt vé khi đến rạp.
                    </div>
                    <p>Cảm ơn bạn đã sử dụng Mobile Cinema.</p>
                  </body>
                </html>
                """;

            return new EmailMessage
            {
                RecipientEmail = recipientEmail,
                Subject = $"Xác nhận đặt vé {booking.BookingCode}",
                Content = content
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
