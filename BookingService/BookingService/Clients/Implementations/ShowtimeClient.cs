using System.Net.Http.Json;
using BookingService.Clients.Interfaces;

namespace BookingService.Clients.Implementations;

public class ShowtimeClient : IShowtimeClient
{
    private readonly HttpClient _httpClient;

    public ShowtimeClient(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<List<ShowtimeSeatInfo>> GetSeatsAsync(
        long showtimeId,
        List<long> seatIds)
    {
        var response = await _httpClient.PostAsJsonAsync(
            $"api/showtimes/{showtimeId}/seats",
            seatIds);

        response.EnsureSuccessStatusCode();

        var result =
            await response.Content
                .ReadFromJsonAsync<List<ShowtimeSeatInfo>>();

        return result ?? new List<ShowtimeSeatInfo>();
    }
}