using System.Text.Json;
using BookingService.Clients.Interfaces;
using BookingService.Configuration;
using BookingService.DTOs.Requests;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;
using BookingService.Validators;
using Microsoft.Extensions.Options;

namespace BookingService.Services.Implementations
{
    public sealed class PaymentService : IPaymentService
    {
        private readonly IPaymentRepository _paymentRepository;
        private readonly IBookingRepository _bookingRepository;
        private readonly IBookingService _bookingService;
        private readonly IPayOsClient _payOsClient;
        private readonly TransactionManager _transactionManager;
        private readonly PayOsOptions _payOsOptions;
        private readonly ILogger<PaymentService> _logger;

        public PaymentService(
            IPaymentRepository paymentRepository,
            IBookingRepository bookingRepository,
            IBookingService bookingService,
            IPayOsClient payOsClient,
            TransactionManager transactionManager,
            IOptions<PayOsOptions> payOsOptions,
            ILogger<PaymentService> logger)
        {
            _paymentRepository = paymentRepository;
            _bookingRepository = bookingRepository;
            _bookingService = bookingService;
            _payOsClient = payOsClient;
            _transactionManager = transactionManager;
            _payOsOptions = payOsOptions.Value;
            _logger = logger;
        }

        public async Task<PagedResult<PaymentResponse>> GetAllPaymentsAsync(
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var payments = await _paymentRepository.GetAllAsync(
                page, size, sortBy, sortDir);

            return new PagedResult<PaymentResponse>
            {
                Items = payments.Select(payment => payment.ToResponse()).ToList(),
                PageNumber = payments.PageNumber,
                PageSize = payments.PageSize,
                TotalPages = payments.TotalPages,
                TotalCount = payments.TotalCount
            };
        }

        public async Task<PagedResult<PaymentResponse>> GetPaymentsByUserAsync(
            long userId,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var payments = await _paymentRepository.GetByUserIdAsync(
                userId, page, size, sortBy, sortDir);

            return new PagedResult<PaymentResponse>
            {
                Items = payments.Select(payment => payment.ToResponse()).ToList(),
                PageNumber = payments.PageNumber,
                PageSize = payments.PageSize,
                TotalPages = payments.TotalPages,
                TotalCount = payments.TotalCount
            };
        }

        public async Task<PagedResult<PaymentResponse>> GetPaymentsByBookingAsync(
            long bookingId,
            int page,
            int size,
            string sortBy,
            string sortDir)
        {
            var payments = await _paymentRepository.GetByBookingIdAsync(
                bookingId, page, size, sortBy, sortDir);

            return new PagedResult<PaymentResponse>
            {
                Items = payments.Select(payment => payment.ToResponse()).ToList(),
                PageNumber = payments.PageNumber,
                PageSize = payments.PageSize,
                TotalPages = payments.TotalPages,
                TotalCount = payments.TotalCount
            };
        }

        public async Task<PaymentResponse> GetPaymentByIdAsync(long id)
        {
            var payment = await GetPaymentAsync(id);
            return payment.ToResponse();
        }

        public async Task<PaymentResponse> GetPaymentByOrderCodeAsync(long orderCode)
        {
            var payment = await _paymentRepository.GetByTransactionRefAsync(
                orderCode.ToString());

            if (payment == null)
            {
                throw new KeyNotFoundException(
                    $"Payment for PayOS order {orderCode} was not found.");
            }

            return payment.ToResponse();
        }

        public async Task<PaymentResponse> CreatePaymentAsync(
            PaymentRequest request)
        {
            PaymentValidator.ValidatePayment(request);

            await using var transaction =
                await _transactionManager.BeginTransactionAsync();

            try
            {
                var booking = await GetBookingForUpdateAsync(
                    request.BookingId!.Value);

                if (booking.UserId != request.UserId!.Value)
                {
                    throw new BusinessException(
                        "Payment user does not match the booking user.");
                }

                EnsurePayableBooking(booking);
                EnsureAmountMatchesBooking(
                    request.Amount!.Value,
                    booking.TotalAmount);

                if (booking.PaymentId.HasValue)
                {
                    throw new ConflictException(
                        "This booking already has a payment.");
                }

                var payment = await _paymentRepository.AddAsync(new Payment
                {
                    PaymentCode = await GeneratePaymentCodeAsync(),
                    BookingId = booking.Id,
                    UserId = booking.UserId,
                    Amount = booking.TotalAmount,
                    Method = request.Method!.Trim().ToUpperInvariant(),
                    Status = "PENDING",
                    CreatedAt = DateTime.Now
                });

                booking.PaymentId = payment.Id;
                await _bookingRepository.UpdateBookingAsync(
                    booking.Id,
                    booking);

                await transaction.CommitAsync();

                return payment.ToResponse();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<PayOsCheckoutResponse> CreatePayOsPaymentAsync(
            PayOsCreateRequest request)
        {
            PaymentValidator.ValidatePayOsCreate(request);

            await using var transaction =
                await _transactionManager.BeginTransactionAsync();

            try
            {
                var booking = await GetBookingForUpdateAsync(
                    request.BookingId!.Value);

                if (booking.UserId != request.UserId!.Value)
                {
                    throw new BusinessException(
                        "Payment user does not match the booking user.");
                }

                EnsurePayableBooking(booking);
                EnsureAmountMatchesBooking(
                    request.Amount!.Value,
                    booking.TotalAmount);

                // A booking always maps to one stable PayOS order code. Retrying
                // the same request therefore reuses the same remote payment.
                var orderCode = GenerateOrderCode(booking.Id);

                if (booking.PaymentId.HasValue)
                {
                    var existingPayment = await GetPaymentAsync(booking.PaymentId.Value);
                    var existingLink = await _payOsClient.GetPaymentStatusAsync(
                        orderCode);

                    await transaction.CommitAsync();

                    return new PayOsCheckoutResponse
                    {
                        paymentId = existingPayment.Id,
                        orderCode = orderCode,
                        checkoutUrl = existingLink.CheckoutUrl
                    };
                }

                var existingPaymentForOrder = await _paymentRepository
                    .GetByTransactionRefAsync(orderCode.ToString());

                if (existingPaymentForOrder != null)
                {
                    if (existingPaymentForOrder.BookingId != booking.Id)
                    {
                        throw new BusinessException(
                            "PayOS order code is already assigned to another booking.");
                    }

                    booking.PaymentId = existingPaymentForOrder.Id;
                    await _bookingRepository.UpdateBookingAsync(
                        booking.Id,
                        booking);
                    await transaction.CommitAsync();

                    return new PayOsCheckoutResponse
                    {
                        paymentId = existingPaymentForOrder.Id,
                        orderCode = orderCode,
                        checkoutUrl = null
                    };
                }

                var amount = booking.TotalAmount;
                var description = (request.Description ?? booking.BookingCode)
                    .Trim();

                // The booking row is locked while the remote request is made,
                // so concurrent retries cannot create another PayOS link.
                var link = await _payOsClient.CreatePaymentLinkAsync(
                    orderCode,
                    amount,
                    description,
                    request.ReturnUrl!,
                    request.CancelUrl!,
                    booking.ExpiresAt);

                var payment = await _paymentRepository.AddAsync(new Payment
                {
                    PaymentCode = await GeneratePaymentCodeAsync(),
                    BookingId = booking.Id,
                    UserId = booking.UserId,
                    Amount = amount,
                    Method = "PAYOS",
                    Status = "PENDING",
                    TransactionRef = orderCode.ToString(),
                    CreatedAt = DateTime.Now
                });

                booking.PaymentId = payment.Id;
                await _bookingRepository.UpdateBookingAsync(
                    booking.Id,
                    booking);

                await transaction.CommitAsync();

                return new PayOsCheckoutResponse
                {
                    paymentId = payment.Id,
                    orderCode = orderCode,
                    checkoutUrl = link.CheckoutUrl
                };
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }

        public async Task<PaymentResponse> ProcessPaymentAsync(
            long id,
            string? recipientEmail)
        {
            var payment = await GetPaymentAsync(id);

            if (!string.Equals(payment.Method, "PAYOS", StringComparison.OrdinalIgnoreCase) ||
                !long.TryParse(payment.TransactionRef, out var orderCode))
            {
                throw new BusinessException(
                    "Only PayOS payments can be processed through this endpoint.");
            }

            return await VerifyPayOsPaymentAsync(orderCode, recipientEmail);
        }

        public Task<PaymentResponse> RefundPaymentAsync(
            long id,
            string fallbackRecipientEmail)
        {
            // PayOS refund requires a separate merchant-side refund flow and
            // must not be simulated by changing the local status only.
            throw new BusinessException(
                "PayOS refund is not available through this service yet.");
        }

        public async Task<PaymentResponse> VerifyPayOsPaymentAsync(
            long orderCode,
            string? recipientEmail)
        {
            var payment = await _paymentRepository.GetByTransactionRefAsync(
                orderCode.ToString());

            if (payment == null)
            {
                throw new KeyNotFoundException(
                    $"Payment for PayOS order {orderCode} was not found.");
            }

            // FAILED cũng hỏi lại PayOS: job hết hạn có thể đã đánh FAILED đúng lúc khách vừa trả tiền
            if (payment.Status is "PENDING" or "FAILED")
            {
                var status = await _payOsClient.GetPaymentStatusAsync(orderCode);
                var normalizedStatus = status.Status.Trim().ToUpperInvariant();

                if (normalizedStatus == "PAID")
                {
                    await MarkPaymentSucceededAsync(payment);
                }
                else if (normalizedStatus is "CANCELLED" or "EXPIRED" &&
                         payment.Status == "PENDING")
                {
                    payment.Status = "FAILED";
                    payment.UpdatedAt = DateTime.Now;
                    await _paymentRepository.UpdateAsync(payment);

                    // Khách bấm huỷ trên trang PayOS: nhả ghế ngay, không chờ hết 10 phút
                    if (normalizedStatus == "CANCELLED")
                    {
                        await _bookingService.CancelUnpaidBookingAsync(payment.BookingId);
                    }
                }
            }

            // PayOS xác nhận đã nhận tiền thì hệ thống mới xác nhận booking. Gọi lại nhiều lần
            // vẫn an toàn (booking đã CONFIRMED thì bỏ qua), nên nếu lần trước lỗi giữa chừng
            // thì lần xác minh sau sẽ xác nhận bù.
            if (payment.Status == "SUCCESS")
            {
                await _bookingService.ConfirmPaidBookingAsync(
                    payment.BookingId,
                    recipientEmail);
            }

            return payment.ToResponse();
        }

        public async Task<PayOsWebhookResult> HandlePayOsWebhookAsync(JsonElement body)
        {
            if (string.IsNullOrWhiteSpace(_payOsOptions.ChecksumKey))
            {
                throw new ServiceUnavailableException(
                    "PayOS credentials are not configured, webhook cannot be verified.");
            }

            // BR-10: chưa kiểm tra chữ ký thì không tin bất kỳ dữ liệu nào trong body
            if (!PayOsSignature.IsValid(body, _payOsOptions.ChecksumKey))
            {
                _logger.LogWarning("Rejected PayOS webhook with an invalid signature.");

                return new PayOsWebhookResult
                {
                    SignatureValid = false,
                    Message = "Invalid signature."
                };
            }

            var data = body.GetProperty("data");

            if (!TryGetString(data, "code", out var code) || code != "00")
            {
                return Accepted($"Ignored: payment result code {code ?? "(none)"}.");
            }

            if (!TryGetLong(data, "orderCode", out var orderCode) ||
                !TryGetLong(data, "amount", out var amount))
            {
                return Accepted("Ignored: orderCode or amount is missing.");
            }

            var payment = await _paymentRepository.GetByTransactionRefAsync(
                orderCode.ToString());

            // PayOS gửi đơn mẫu (orderCode 123) khi đăng ký URL webhook: trả 200 để xác nhận URL
            if (payment == null)
            {
                _logger.LogInformation(
                    "PayOS webhook for unknown order {OrderCode} was ignored.",
                    orderCode);

                return Accepted($"Ignored: order {orderCode} was not found.");
            }

            if (amount != decimal.ToInt64(decimal.Truncate(payment.Amount)))
            {
                _logger.LogError(
                    "PayOS webhook amount {Amount} does not match payment {PaymentId} amount {Expected}.",
                    amount,
                    payment.Id,
                    payment.Amount);

                return Accepted("Ignored: amount does not match the payment.");
            }

            await MarkPaymentSucceededAsync(payment);

            try
            {
                var booking = await _bookingService.ConfirmPaidBookingAsync(
                    payment.BookingId,
                    null);

                return Accepted($"Booking {booking.BookingCode} is confirmed.");
            }
            // Tiền đã về nhưng không giữ được ghế (booking đã huỷ / ghế đã bán cho người khác): rạp hoàn tiền
            catch (ConflictException ex)
            {
                _logger.LogWarning(
                    "Payment {PaymentId} succeeded but booking {BookingId} could not be confirmed: {Reason}",
                    payment.Id,
                    payment.BookingId,
                    ex.Message);

                return Accepted(ex.Message);
            }
        }

        public async Task MarkUnpaidPaymentFailedAsync(long paymentId)
        {
            var payment = await _paymentRepository.GetByIdAsync(paymentId);

            if (payment == null || payment.Status != "PENDING")
            {
                return;
            }

            payment.Status = "FAILED";
            payment.UpdatedAt = DateTime.Now;
            await _paymentRepository.UpdateAsync(payment);
        }

        private async Task MarkPaymentSucceededAsync(Payment payment)
        {
            if (payment.Status == "SUCCESS")
            {
                return;
            }

            payment.Status = "SUCCESS";
            payment.UpdatedAt = DateTime.Now;
            await _paymentRepository.UpdateAsync(payment);
        }

        private static PayOsWebhookResult Accepted(string message)
        {
            return new PayOsWebhookResult
            {
                SignatureValid = true,
                Message = message
            };
        }

        private static bool TryGetString(JsonElement data, string name, out string? value)
        {
            value = data.TryGetProperty(name, out var element) &&
                    element.ValueKind == JsonValueKind.String
                ? element.GetString()
                : null;

            return value != null;
        }

        private static bool TryGetLong(JsonElement data, string name, out long value)
        {
            value = 0;

            return data.TryGetProperty(name, out var element) &&
                   element.ValueKind == JsonValueKind.Number &&
                   element.TryGetInt64(out value);
        }

        private async Task<Payment> GetPaymentAsync(long id)
        {
            var payment = await _paymentRepository.GetByIdAsync(id);

            if (payment == null)
            {
                throw new KeyNotFoundException(
                    $"Payment with id {id} was not found.");
            }

            return payment;
        }

        private async Task<Booking> GetBookingForUpdateAsync(long id)
        {
            var booking = await _bookingRepository
                .GetBookingByIdForUpdateAsync(id);

            if (booking == null)
            {
                throw new KeyNotFoundException(
                    $"Booking with id {id} was not found.");
            }

            return booking;
        }

        private static void EnsurePayableBooking(Booking booking)
        {
            if (!string.Equals(booking.Status, "PENDING", StringComparison.OrdinalIgnoreCase))
            {
                throw new ConflictException(
                    "Only PENDING bookings can be paid.");
            }

            if (booking.ExpiresAt.HasValue && booking.ExpiresAt <= DateTime.Now)
            {
                throw new ConflictException("Booking has expired.");
            }
        }

        private static void EnsureAmountMatchesBooking(
            decimal requestedAmount,
            decimal bookingAmount)
        {
            if (requestedAmount != bookingAmount)
            {
                throw new BusinessException(
                    "Payment amount does not match the booking amount.");
            }
        }

        private async Task<string> GeneratePaymentCodeAsync()
        {
            for (var attempt = 0; attempt < 5; attempt++)
            {
                var code = $"PAY-{DateTime.Now:yyyyMMddHHmmss}-{Random.Shared.Next(100000, 999999)}";

                if (!await _paymentRepository.ExistsByPaymentCodeAsync(code))
                {
                    return code;
                }
            }

            throw new BusinessException(
                "Could not generate a unique payment code.");
        }

        private static long GenerateOrderCode(long bookingId)
        {
            if (bookingId <= 0)
            {
                throw new BusinessException("Booking id must be positive.");
            }

            return bookingId;
        }
    }
}
