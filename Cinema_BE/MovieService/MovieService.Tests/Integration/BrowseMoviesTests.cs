using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MovieService.Tests.Infrastructure;

namespace MovieService.Tests.Integration;

// Trang chủ của khách: tab Đang chiếu / Sắp chiếu, lọc thể loại, tìm theo tên (chỉ phim ACTIVE)
[Collection(MovieApiCollection.Name)]
public class BrowseMoviesTests
{
    private readonly MovieApiFactory _factory;
    private readonly HttpClient _admin;
    private readonly HttpClient _guest;

    public BrowseMoviesTests(MovieApiFactory factory)
    {
        _factory = factory;
        _admin = factory.ClientFor(TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN"));
        _guest = factory.CreateClient();
    }

    [Fact]
    public async Task NowShowingAndComingSoon_SplitByReleaseDate_AndFilterByGenreAndTitle()
    {
        var tag = Guid.NewGuid().ToString("N")[..8];
        var genre = $"Noir{tag}";
        var today = DateTime.Today;
        var showing = await CreateAsync($"Showing {tag}", today.AddDays(-30), $"Hành động, {genre}");
        var opensToday = await CreateAsync($"Opens today {tag}", today, "Hài hước");
        var later = await CreateAsync($"Later {tag}", today.AddDays(20), genre);
        var sooner = await CreateAsync($"Sooner {tag}", today.AddDays(5), "Hài hước");
        var stopped = await CreateAsync($"Stopped {tag}", today.AddDays(-10), genre);
        Assert.Equal(HttpStatusCode.NoContent, (await _admin.DeleteAsync($"/api/v1/movies/{stopped}")).StatusCode);

        // Đang chiếu: đã khởi chiếu (kể cả hôm nay), mới thêm trước; phim đã ngừng không hiện
        Assert.Equal([opensToday, showing], await IdsAsync($"/api/v1/movies/browse?keyword={tag}"));
        // Sắp chiếu: khởi chiếu sớm nhất trước
        Assert.Equal([sooner, later], await IdsAsync($"/api/v1/movies/browse?when=soon&keyword={tag.ToUpperInvariant()}"));

        // Thể loại khớp một trong các thể loại của phim, không phân biệt hoa thường
        Assert.Equal([showing], await IdsAsync($"/api/v1/movies/browse?genre={genre.ToLowerInvariant()}"));
        Assert.Equal([later], await IdsAsync($"/api/v1/movies/browse?when=soon&genre={genre}"));

        // % trong từ khoá không phải ký tự đại diện
        Assert.Empty(await IdsAsync($"/api/v1/movies/browse?keyword={tag}%25x"));

        Assert.Equal(HttpStatusCode.BadRequest, (await _guest.GetAsync("/api/v1/movies/browse?when=later")).StatusCode);

        var genres = await _guest.GetFromJsonAsync<List<string>>("/api/v1/movies/genres");
        Assert.Contains(genre, genres!);
        Assert.Contains("Hành động", genres!);
        Assert.Equal(genres!.Count, genres.Distinct(StringComparer.OrdinalIgnoreCase).Count());
    }

    private async Task<long> CreateAsync(string title, DateTime releaseDate, string genre)
    {
        var created = await _admin.PostAsJsonAsync("/api/v1/movies", new
        {
            title,
            description = "Phim thử",
            durationMinutes = 100,
            genre,
            language = "Vietnamese",
            releaseDate,
            posterUrl = "https://example.com/poster.jpg"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        return (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetInt64();
    }

    private async Task<List<long>> IdsAsync(string url)
    {
        var page = await _guest.GetFromJsonAsync<JsonElement>(url + "&size=50");
        return page.GetProperty("items").EnumerateArray().Select(m => m.GetProperty("id").GetInt64()).ToList();
    }
}
