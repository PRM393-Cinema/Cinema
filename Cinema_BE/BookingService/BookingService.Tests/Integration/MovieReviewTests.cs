using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using BookingService.Tests.Infrastructure;
using static BookingService.Tests.Infrastructure.BookingApi;

namespace BookingService.Tests.Integration;

// Đánh giá phim: chỉ khách đã xem (vé đã check-in) mới viết được, mỗi khách một đánh giá cho một phim
// (gửi lại là sửa); ai cũng xem được điểm trung bình và danh sách; chủ đánh giá hoặc Admin xoá được.
// Mỗi test dùng một khách riêng vì đánh giá gắn với (khách, phim).
[Collection(BookingApiCollection.Name)]
public class MovieReviewTests
{
    private static long _nextReviewer = 9500;

    private readonly BookingApiFactory _factory;
    private readonly HttpClient _staff;

    public MovieReviewTests(BookingApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(TestUsers.StaffToken);
    }

    [Fact]
    public async Task OnlyCustomersWhoWatched_CanReview_AndSendingAgainEdits()
    {
        var (email, customer) = NewCustomer();
        var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddHours(1));
        var movieId = showtime.MovieId;
        var bookingId = await CreatePaidBookingAsync(_factory, customer, showtime.Id, NewSeat());

        // Đã trả tiền nhưng chưa check-in thì chưa được đánh giá
        var before = await customer.GetFromJsonAsync<JsonElement>($"/api/v1/reviews/booking/{bookingId}");
        Assert.False(before.GetProperty("canReview").GetBoolean());
        Assert.Equal(movieId, before.GetProperty("movieId").GetInt64());
        var early = await customer.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating = 5, comment = "Hay" });
        Assert.Equal(HttpStatusCode.BadRequest, early.StatusCode);
        Assert.Contains("checked in", await early.Content.ReadAsStringAsync());

        Assert.Equal(HttpStatusCode.OK, (await _staff.PostAsync($"/api/v1/bookings/{bookingId}/check-in", null)).StatusCode);

        // Vé của người khác, số sao sai
        var (_, stranger) = NewCustomer();
        Assert.Equal(HttpStatusCode.NotFound,
            (await stranger.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating = 4 })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await customer.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating = 6 })).StatusCode);

        var created = await customer.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating = 4, comment = "  Hình đẹp  " });
        Assert.Equal(HttpStatusCode.OK, created.StatusCode);
        var review = await created.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Hình đẹp", review.GetProperty("comment").GetString());
        // Token không có họ tên: hiện email đã che bớt
        Assert.Equal($"{email[..3]}***@test.local", review.GetProperty("reviewerName").GetString());

        // Gửi lại là sửa đánh giá cũ, không tạo thêm
        var edited = await (await customer.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating = 2 }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(review.GetProperty("id").GetInt64(), edited.GetProperty("id").GetInt64());
        Assert.Equal(2, edited.GetProperty("rating").GetInt32());
        Assert.Equal(JsonValueKind.Null, edited.GetProperty("comment").ValueKind);

        var forBooking = await customer.GetFromJsonAsync<JsonElement>($"/api/v1/reviews/booking/{bookingId}");
        Assert.True(forBooking.GetProperty("canReview").GetBoolean());
        Assert.Equal(2, forBooking.GetProperty("review").GetProperty("rating").GetInt32());
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/reviews/booking/{bookingId}")).StatusCode);

        var mine = await customer.GetFromJsonAsync<JsonElement>("/api/v1/reviews/mine");
        var only = Assert.Single(mine.EnumerateArray());
        Assert.Equal(movieId, only.GetProperty("movieId").GetInt64());

        // Khách chưa đăng nhập xem được; người viết thấy đánh giá của mình
        var guestView = await _factory.CreateClient().GetFromJsonAsync<JsonElement>($"/api/v1/reviews/movie/{movieId}?size=50");
        var shown = guestView.GetProperty("reviews").GetProperty("items").EnumerateArray()
            .Single(item => item.GetProperty("id").GetInt64() == review.GetProperty("id").GetInt64());
        Assert.False(shown.GetProperty("mine").GetBoolean());
        var ownView = await customer.GetFromJsonAsync<JsonElement>($"/api/v1/reviews/movie/{movieId}?size=50");
        Assert.Contains(ownView.GetProperty("reviews").GetProperty("items").EnumerateArray(),
            item => item.GetProperty("mine").GetBoolean());
    }

    [Fact]
    public async Task TheAverageCountsEveryStar_AndOwnerOrAdminCanDelete()
    {
        // Phim riêng để điểm trung bình không lẫn với test khác
        var movieId = 900 + Interlocked.Increment(ref _nextReviewer);
        var reviews = new List<(long Id, HttpClient Client)>();
        foreach (var rating in new[] { 5, 4, 4 })
        {
            var (_, customer) = NewCustomer();
            var showtime = _factory.Showtimes.AddShowtime(DateTime.Now.AddHours(1), movieId: movieId);
            var bookingId = await CreatePaidBookingAsync(_factory, customer, showtime.Id, NewSeat());
            await _staff.PostAsync($"/api/v1/bookings/{bookingId}/check-in", null);
            var saved = await (await customer.PostAsJsonAsync("/api/v1/reviews", new { bookingId, rating }))
                .Content.ReadFromJsonAsync<JsonElement>();
            reviews.Add((saved.GetProperty("id").GetInt64(), customer));
        }

        var summary = await _factory.CreateClient().GetFromJsonAsync<JsonElement>($"/api/v1/reviews/movie/{movieId}");
        Assert.Equal(3, summary.GetProperty("count").GetInt32());
        Assert.Equal(4.3, summary.GetProperty("average").GetDouble());
        Assert.Equal([0, 0, 0, 2, 1], summary.GetProperty("stars").EnumerateArray().Select(s => s.GetInt32()));

        // Người khác không xoá được; chủ đánh giá và Admin thì được
        Assert.Equal(HttpStatusCode.Forbidden, (await reviews[1].Client.DeleteAsync($"/api/v1/reviews/{reviews[0].Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await reviews[0].Client.DeleteAsync($"/api/v1/reviews/{reviews[0].Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent,
            (await _factory.ClientFor(TestUsers.AdminToken).DeleteAsync($"/api/v1/reviews/{reviews[1].Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await reviews[1].Client.DeleteAsync($"/api/v1/reviews/{reviews[1].Id}")).StatusCode);

        summary = await _factory.CreateClient().GetFromJsonAsync<JsonElement>($"/api/v1/reviews/movie/{movieId}");
        Assert.Equal(1, summary.GetProperty("count").GetInt32());
        Assert.Equal(4.0, summary.GetProperty("average").GetDouble());
    }

    private (string Email, HttpClient Client) NewCustomer()
    {
        var id = Interlocked.Increment(ref _nextReviewer);
        var email = $"review{id}@test.local";
        return (email, _factory.ClientFor(TestJwt.Create(id, email, "ROLE_CUSTOMER")));
    }
}
