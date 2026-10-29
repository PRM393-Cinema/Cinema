using BookingService.Messaging;
using BookingService.Messaging.Handlers;

namespace BookingService.Tests.Unit;

public class EmailTemplatesTests
{
    private static BookingEventData Booking(string movieTitle = "Phim Hay")
    {
        return new BookingEventData
        {
            BookingId = 1,
            BookingCode = "BK-1",
            UserId = 3,
            CustomerEmail = "khach@test.local",
            MovieTitle = movieTitle,
            ShowTime = new DateTime(2026, 12, 20, 19, 30, 0),
            Seats = new List<string> { "A1", "A2" },
            TotalAmount = 180_000,
            Status = "CONFIRMED"
        };
    }

    [Fact]
    public void BookingConfirmed_ContainsTicketDetails()
    {
        var email = EmailTemplates.BookingConfirmed(Booking(), "khach@test.local");

        Assert.Equal("khach@test.local", email.RecipientEmail);
        Assert.Contains("BK-1", email.Subject);
        Assert.Contains("A1, A2", email.Content);
        Assert.Contains("20/12/2026 19:30", email.Content);
    }

    [Fact]
    public void BookingConfirmed_CarriesTheTicketQrCode()
    {
        var email = EmailTemplates.BookingConfirmed(Booking(), "khach@test.local");

        var qr = Assert.Single(email.InlineImages);
        Assert.Equal("image/png", qr.MediaType);
        Assert.Equal(new byte[] { 0x89, 0x50, 0x4E, 0x47 }, qr.Content.Take(4));
        Assert.Contains($"cid:{qr.ContentId}", email.Content);

        // Other emails have no ticket to show
        Assert.Empty(EmailTemplates.BookingExpired(Booking(), "khach@test.local").InlineImages);
    }

    [Fact]
    public void Templates_EncodeTextThatComesFromUsers()
    {
        var email = EmailTemplates.BookingConfirmed(Booking("<script>alert(1)</script>"), "khach@test.local");

        Assert.DoesNotContain("<script>", email.Content);
        Assert.Contains("&lt;script&gt;", email.Content);
    }

    [Fact]
    public void BookingCancelled_MentionsRefund_OnlyWhenBookingWasPaid()
    {
        var paid = Booking();
        paid.PreviousStatus = "CONFIRMED";
        paid.PaymentId = 9;

        var unpaid = Booking();
        unpaid.PreviousStatus = "PENDING";

        Assert.Contains("hoàn tiền", EmailTemplates.BookingCancelled(paid, "k@test.local").Content);
        Assert.DoesNotContain("hoàn tiền", EmailTemplates.BookingCancelled(unpaid, "k@test.local").Content);
    }

    [Fact]
    public void RefundRejected_EncodesReason()
    {
        var email = EmailTemplates.RefundRejected(new PaymentEventData
        {
            BookingCode = "BK-1", RefundCode = "RF-1", Reason = "<script>unsafe</script>"
        }, "khach@test.local");
        Assert.Contains("BK-1", email.Subject);
        Assert.Contains("RF-1", email.Content);
        Assert.Contains("&lt;script&gt;", email.Content);
        Assert.DoesNotContain("<script>", email.Content);
    }

    [Fact]
    public void RefundCompleted_ShowsTransactionReference()
    {
        var email = EmailTemplates.RefundCompleted(new PaymentEventData
        {
            BookingCode = "BK-1",
            Amount = 90_000,
            RefundAmount = 90_000,
            RefundTransactionRef = "FT123"
        }, "khach@test.local");

        Assert.Contains("FT123", email.Content);
        Assert.Contains("BK-1", email.Subject);
    }
}
