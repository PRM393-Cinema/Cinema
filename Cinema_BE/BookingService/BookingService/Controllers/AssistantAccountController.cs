using System.ComponentModel.DataAnnotations;
using System.Data;
using BookingService.Data;
using BookingService.Helpers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Controllers;

// Read-only, owner-scoped facts; the model never chooses a user id or calculates money.
[ApiController, Authorize, Route("api/v1/bookings/assistant-summary")]
public sealed class AssistantAccountController(BookingDbContext bookings, PaymentDbContext payments) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
        [FromQuery, StringLength(100)] string? query, [FromQuery, Range(1, 10000)] int page = 1,
        CancellationToken cancellationToken = default)
    {
        if (from > to || to == DateOnly.MaxValue)
            return BadRequest(new { detail = "Invalid inclusive date range." });
        var userId = User.GetCurrentUserId();
        // Keep totals and the highest payment consistent if a payment/refund arrives during the read.
        await using var snapshot = await payments.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead, cancellationToken);
        var start = from?.ToDateTime(TimeOnly.MinValue);
        var end = to?.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var ownPayments = payments.Payments.AsNoTracking().Where(p => p.UserId == userId);
        var ownBookings = bookings.Bookings.AsNoTracking().Where(b => b.UserId == userId);
        if (start.HasValue)
        {
            ownPayments = ownPayments.Where(p => p.CreatedAt >= start.Value);
            ownBookings = ownBookings.Where(b => b.CreatedAt >= start.Value);
        }
        if (end.HasValue)
        {
            ownPayments = ownPayments.Where(p => p.CreatedAt < end.Value);
            ownBookings = ownBookings.Where(b => b.CreatedAt < end.Value);
        }
        // Search narrows rows, but totals always cover the whole requested date range.
        var paid = ownPayments.Where(p => p.Status == "SUCCESS" || p.Status == "REFUND_PENDING" || p.Status == "REFUNDED");
        var grossPaid = await paid.SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0;
        var refunded = await ownPayments.Where(p => p.Status == "REFUNDED")
            .SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0;
        var highest = await paid.OrderByDescending(p => p.Amount).ThenByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id)
            .Select(p => new { p.PaymentCode, p.BookingId, p.Amount, p.Method, p.Status, p.CreatedAt })
            .FirstOrDefaultAsync(cancellationToken);
        var bookingCount = await ownBookings.CountAsync(cancellationToken);
        var paymentCount = await ownPayments.CountAsync(cancellationToken);
        if (!string.IsNullOrWhiteSpace(query))
        {
            var term = query.Trim().ToLowerInvariant();
            ownPayments = ownPayments.Where(p => p.PaymentCode.ToLower().Contains(term));
            ownBookings = ownBookings.Where(b => b.BookingCode.ToLower().Contains(term) ||
                (b.MovieTitle != null && b.MovieTitle.ToLower().Contains(term)));
        }
        return Ok(new
        {
            currency = "VND", timeZone = "Asia/Ho_Chi_Minh", from, to,
            dateBasis = "Creation date, inclusive local calendar days. Totals ignore the text search.",
            grossPaid, refunded, netPaid = grossPaid - refunded, highestPaidPayment = highest,
            paidDefinition = "SUCCESS + REFUND_PENDING + REFUNDED; pending refunds remain paid until REFUNDED. Net subtracts completed refunds.",
            bookingCount, paymentCount, page, pageSize = 10,
            matchingBookings = await ownBookings.CountAsync(cancellationToken),
            matchingPayments = await ownPayments.CountAsync(cancellationToken),
            bookings = await ownBookings.OrderByDescending(b => b.CreatedAt).ThenByDescending(b => b.Id)
                .Skip((page - 1) * 10).Take(10)
                .Select(b => new { b.Id, b.BookingCode, b.MovieTitle, b.ShowTime, b.Status, b.TotalAmount, b.CreatedAt })
                .ToListAsync(cancellationToken),
            payments = await ownPayments.OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id)
                .Skip((page - 1) * 10).Take(10)
                .Select(p => new { p.PaymentCode, p.BookingId, p.Amount, p.Method, p.Status, p.CreatedAt })
                .ToListAsync(cancellationToken)
        });
    }
}
