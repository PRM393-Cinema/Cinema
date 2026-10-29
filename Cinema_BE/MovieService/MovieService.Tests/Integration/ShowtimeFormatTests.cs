using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MovieService.Tests.Infrastructure;

namespace MovieService.Tests.Integration;

// Định dạng suất chiếu 2D / 3D / IMAX: phụ thu 3D +20.000đ, IMAX +40.000đ cộng vào giá ghế thường,
// rồi mới tính phụ thu theo loại ghế; giá ghế gửi cho BookingService cũng gồm phụ thu
[Collection(MovieApiCollection.Name)]
public class ShowtimeFormatTests
{
    private readonly MovieApiFactory _factory;
    private readonly HttpClient _staff;

    public ShowtimeFormatTests(MovieApiFactory factory)
    {
        _factory = factory;
        _staff = factory.ClientFor(MovieApiFactory.StaffToken);
    }

    private object Body(DateTime start, string? format, decimal price = 90_000) => new
    {
        movieId = _factory.MovieId,
        roomId = _factory.RoomId,
        startTime = start,
        endTime = start.AddHours(2),
        price,
        format
    };

    [Fact]
    public async Task FormatsAddTheirSurcharge_DefaultTo2D_AndKeepWhenLeftOut()
    {
        var start = _factory.NextFreeDay();
        var created = await _staff.PostAsJsonAsync("/api/showtimes", Body(start, "imax"));
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var show = await created.Content.ReadFromJsonAsync<JsonElement>();
        var id = show.GetProperty("id").GetInt64();

        // Giá lưu là giá 2D; IMAX cộng 40.000đ rồi VIP +20%, sweetbox +30%
        Assert.Equal("IMAX", show.GetProperty("format").GetString());
        Assert.Equal(90_000m, show.GetProperty("price").GetDecimal());
        Assert.Equal(40_000m, show.GetProperty("formatSurcharge").GetDecimal());
        var prices = show.GetProperty("seatPrices");
        Assert.Equal(130_000m, prices.GetProperty("NORMAL").GetDecimal());
        Assert.Equal(156_000m, prices.GetProperty("VIP").GetDecimal());
        Assert.Equal(169_000m, prices.GetProperty("SWEETBOX").GetDecimal());

        // Giá ghế BookingService dùng để tính tiền vé
        var seats = await _factory.ClientFor(MovieApiFactory.CustomerToken)
            .PostAsJsonAsync($"/api/showtimes/{id}/seats", _factory.SeatIds.Take(1));
        Assert.Equal(130_000m, (await seats.Content.ReadFromJsonAsync<JsonElement>())[0].GetProperty("price").GetDecimal());

        // Sửa mà bỏ trống định dạng thì giữ nguyên; đổi sang 3D thì +20.000đ
        var kept = await _staff.PutAsJsonAsync($"/api/showtimes/{id}", Body(start, null, 100_000));
        Assert.Equal("IMAX", (await kept.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("format").GetString());
        var threeD = await (await _staff.PutAsJsonAsync($"/api/showtimes/{id}", Body(start, "3d", 100_000)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("3D", threeD.GetProperty("format").GetString());
        Assert.Equal(120_000m, threeD.GetProperty("seatPrices").GetProperty("NORMAL").GetDecimal());

        Assert.Equal(HttpStatusCode.BadRequest,
            (await _staff.PutAsJsonAsync($"/api/showtimes/{id}", Body(start, "4DX"))).StatusCode);

        var plain = await (await _staff.PostAsJsonAsync("/api/showtimes", Body(start.AddHours(4), null)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("2D", plain.GetProperty("format").GetString());
        Assert.Equal(90_000m, plain.GetProperty("seatPrices").GetProperty("NORMAL").GetDecimal());
    }
}
