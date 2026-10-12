using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MovieService.Tests.Infrastructure;

namespace MovieService.Tests.Integration;

[Collection(MovieApiCollection.Name)]
public class MovieActivationTests(MovieApiFactory factory)
{
    [Fact]
    public async Task AdminCanReactivateWithoutChangingMovieDetails()
    {
        var admin = factory.ClientFor(TestJwt.Create(301, "admin@test.local", "ROLE_ADMIN"));
        var created = await admin.PostAsJsonAsync("/api/v1/movies", new
        {
            title = $"Reactivation {Guid.NewGuid()}",
            description = "Retain this description",
            durationMinutes = 120,
            genre = "Drama",
            language = "Vietnamese",
            releaseDate = "2026-10-11",
            posterUrl = "https://example.com/poster.jpg",
            trailerUrl = "https://example.com/trailer"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var original = await created.Content.ReadFromJsonAsync<JsonElement>();
        var id = original.GetProperty("id").GetInt64();
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/v1/movies/{id}")).StatusCode);
        var inactive = await admin.GetFromJsonAsync<JsonElement>($"/api/v1/movies/{id}");
        Assert.Equal("INACTIVE", inactive.GetProperty("status").GetString());

        for (var attempt = 0; attempt < 2; attempt++)
        {
            var activated = await admin.PatchAsync($"/api/v1/movies/{id}/activate", null);
            Assert.Equal(HttpStatusCode.OK, activated.StatusCode);
            var result = await activated.Content.ReadFromJsonAsync<JsonElement>();
            foreach (var property in inactive.EnumerateObject())
                Assert.Equal(property.Name == "status" ? "ACTIVE" : property.Value.ToString(),
                    result.GetProperty(property.Name).ToString());
        }

        var persisted = await admin.GetFromJsonAsync<JsonElement>($"/api/v1/movies/{id}");
        Assert.Equal("ACTIVE", persisted.GetProperty("status").GetString());
        Assert.Equal(HttpStatusCode.NotFound,
            (await admin.PatchAsync($"/api/v1/movies/{long.MaxValue}/activate", null)).StatusCode);
    }

    [Theory]
    [InlineData(null, HttpStatusCode.Unauthorized)]
    [InlineData("ROLE_CUSTOMER", HttpStatusCode.Forbidden)]
    [InlineData("ROLE_STAFF", HttpStatusCode.Forbidden)]
    public async Task OnlyAdminCanActivate(string? role, HttpStatusCode expected)
    {
        var client = factory.ClientFor(role == null ? null : TestJwt.Create(401, "user@test.local", role));
        Assert.Equal(expected,
            (await client.PatchAsync($"/api/v1/movies/{factory.MovieId}/activate", null)).StatusCode);
    }
}
