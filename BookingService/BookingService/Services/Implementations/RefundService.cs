using BookingService.Data;
using BookingService.DTOs.Responses;
using BookingService.Exceptions;
using BookingService.Helpers;
using BookingService.Mapping;
using BookingService.Messaging;
using BookingService.Models;
using BookingService.Repositories.Interfaces;
using BookingService.Services.Interfaces;

namespace BookingService.Services.Implementations
{
    public sealed class RefundService : IRefundService
    {
        private readonly IRefundRepository _refundRepository;
        private readonly IPaymentRepository _paymentRepository;
        private readonly IBookingRepository _bookingRepository;
        private readonly OutboxWriter<PaymentDbContext> _outbox;
        private readonly ILogger<RefundService> _logger;

        public RefundService(
            IRefundRepository refundRepository,
            IPaymentRepository paymentRepository,
            IBookingRepository bookingRepository,
            OutboxWriter<PaymentDbContext> outbox,
            ILogger<RefundService> logger)
        {
            _refundRepository = refundRepository;
            _paymentRepository = paymentRepository;
            _bookingRepository = bookingRepository;
            _outbox = outbox;
            _logger = logger;
        }

        public async Task<RefundResponse> RequestRefundAsync(long paymentId, string reason)
        {
            await using var transaction = await _outbox.BeginTransactionAsync();

            // Khoá payment: staff bấm hoàn tiền cùng lúc consumer xử lý booking.cancelled cũng chỉ tạo một yêu cầu
            var payment = await _paymentRepository.GetByIdForUpdateAsync(paymentId)
                ?? throw new KeyNotFoundException($"Payment with id {paymentId} was not found.");

            var booking = await _bookingRepository.GetBookingByIdAsync(payment.BookingId);

            var existing = await _refundRepository.GetByPaymentIdAsync(paymentId);

            if (existing != null)
            {
                await transaction.CommitAsync();
                return existing.ToResponse(payment);
            }

            if (payment.Status != "SUCCESS")
            {
                throw new ConflictException(
                    $"Payment {payment.PaymentCode} is {payment.Status}, only paid payments can be refunded.");
            }

            var now = DateTime.Now;

            var refund = await _refundRepository.AddAsync(new Refund
            {
                RefundCode = await GenerateRefundCodeAsync(),
                PaymentId = payment.Id,
                BookingId = payment.BookingId,
                UserId = payment.UserId,
                Amount = payment.Amount,
                Reason = Truncate(string.IsNullOrWhiteSpace(reason) ? "Refund requested." : reason.Trim(), 255),
                Status = "PENDING",
                CreatedAt = now
            });

            payment.Status = "REFUND_PENDING";
            payment.UpdatedAt = now;

            _outbox.Add(
                EventTypes.PaymentRefundRequested,
                EventFactory.Payment(payment, booking, refund));

            await _paymentRepository.UpdateAsync(payment);
            await transaction.CommitAsync();

            _logger.LogInformation(
                "Refund {RefundCode} of {Amount} requested for payment {PaymentId}: {Reason}",
                refund.RefundCode,
                refund.Amount,
                payment.Id,
                refund.Reason);

            return refund.ToResponse(payment);
        }

        public async Task<RefundResponse?> RequestRefundForBookingAsync(long bookingId, string reason)
        {
            var paidPayment = await _paymentRepository.GetLatestByBookingIdAsync(
                bookingId,
                "SUCCESS", "REFUND_PENDING", "REFUNDED");

            if (paidPayment == null)
            {
                return null;
            }

            return await RequestRefundAsync(paidPayment.Id, reason);
        }

        public async Task<RefundResponse> CompleteRefundAsync(
            long refundId,
            string transactionRef,
            string? note,
            long processedBy)
        {
            await using var transaction = await _outbox.BeginTransactionAsync();

            // Khoá refund rồi payment: hai Staff cùng bấm xác nhận thì người sau nhận 409
            var refund = await _refundRepository.GetByIdForUpdateAsync(refundId)
                ?? throw new KeyNotFoundException($"Refund with id {refundId} was not found.");

            if (refund.Status == "COMPLETED")
            {
                throw new ConflictException(
                    $"Refund {refund.RefundCode} has already been completed.");
            }

            var payment = await _paymentRepository.GetByIdForUpdateAsync(refund.PaymentId)
                ?? throw new KeyNotFoundException($"Payment with id {refund.PaymentId} was not found.");

            var booking = await _bookingRepository.GetBookingByIdAsync(refund.BookingId);

            var now = DateTime.Now;

            refund.Status = "COMPLETED";
            refund.TransactionRef = transactionRef.Trim();
            refund.Note = string.IsNullOrWhiteSpace(note) ? null : Truncate(note.Trim(), 500);
            refund.ProcessedBy = processedBy;
            refund.ProcessedAt = now;

            payment.Status = "REFUNDED";
            payment.UpdatedAt = now;

            _outbox.Add(
                EventTypes.PaymentRefunded,
                EventFactory.Payment(payment, booking, refund));

            await _refundRepository.UpdateAsync(refund);
            await transaction.CommitAsync();

            return refund.ToResponse(payment);
        }

        public async Task<PagedResult<RefundResponse>> GetRefundsAsync(string? status, int page, int size)
        {
            var paging = PaginationUtils.Normalize(page, size, "createdAt", "desc");

            var refunds = await _refundRepository.GetAllAsync(
                status,
                paging.PageNumber,
                paging.PageSize);

            var payments = (await _paymentRepository.GetByIdsAsync(
                    refunds.Select(refund => refund.PaymentId).Distinct().ToList()))
                .ToDictionary(payment => payment.Id);

            return new PagedResult<RefundResponse>
            {
                Items = refunds
                    .Select(refund => refund.ToResponse(payments.GetValueOrDefault(refund.PaymentId)))
                    .ToList(),
                PageNumber = refunds.PageNumber,
                PageSize = refunds.PageSize,
                TotalPages = refunds.TotalPages,
                TotalCount = refunds.TotalCount
            };
        }

        public async Task<RefundResponse> GetRefundByIdAsync(long id)
        {
            var refund = await _refundRepository.GetByIdAsync(id)
                ?? throw new KeyNotFoundException($"Refund with id {id} was not found.");

            return refund.ToResponse(await _paymentRepository.GetByIdAsync(refund.PaymentId));
        }

        public async Task<RefundResponse> GetRefundByPaymentIdAsync(long paymentId)
        {
            var refund = await _refundRepository.GetByPaymentIdAsync(paymentId)
                ?? throw new KeyNotFoundException($"Payment with id {paymentId} has no refund.");

            return refund.ToResponse(await _paymentRepository.GetByIdAsync(paymentId));
        }

        private async Task<string> GenerateRefundCodeAsync()
        {
            for (var attempt = 0; attempt < 5; attempt++)
            {
                var code = $"RF-{DateTime.Now:yyyyMMddHHmmss}-{Random.Shared.Next(100000, 999999)}";

                if (!await _refundRepository.ExistsByRefundCodeAsync(code))
                {
                    return code;
                }
            }

            throw new BusinessException("Could not generate a unique refund code.");
        }

        private static string Truncate(string value, int maxLength)
        {
            return value.Length <= maxLength ? value : value[..maxLength];
        }
    }
}
