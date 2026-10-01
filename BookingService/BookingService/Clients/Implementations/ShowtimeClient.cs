using System.Net;
using System.Net.Http.Json;
using BookingService.Clients.Interfaces;
using BookingService.Exceptions;
using Microsoft.AspNetCore.Mvc;

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
        HttpResponseMessage response;

        try
        {
            response = await _httpClient.PostAsJsonAsync(
                $"api/showtimes/{showtimeId}/seats",
                seatIds);
        }
        catch (System.Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            throw new ExternalServiceException(
                "Showtime service is unavailable. Please try again later.");
        }

        if (response.IsSuccessStatusCode)
        {
            var result =
                await response.Content
                    .ReadFromJsonAsync<List<ShowtimeSeatInfo>>();

            return result ?? new List<ShowtimeSeatInfo>();
        }

        // MovieService trả ProblemDetails: chuyển lỗi nghiệp vụ về đúng mã thay vì 500.
        var detail = await ReadErrorDetailAsync(response);

        System.Exception error = response.StatusCode switch
        {
            HttpStatusCode.NotFound => new NotFoundException(
                detail ?? $"Showtime with ID {showtimeId} was not found."),
            HttpStatusCode.BadRequest => new BusinessException(
                detail ?? "One or more selected seats are invalid for this showtime."),
            HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden => new ExternalServiceException(
                $"Showtime service rejected the request ({(int)response.StatusCode}). " +
                "Check that Jwt:SecretKey is the same in MovieService and BookingService."),
            _ => new ExternalServiceException(
                $"Showtime service returned status {(int)response.StatusCode}.")
        };

        throw error;
    }

    private static async Task<string?> ReadErrorDetailAsync(HttpResponseMessage response)
    {
        try
        {
            var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>();
            return string.IsNullOrWhiteSpace(problem?.Detail) ? null : problem.Detail;
        }
        catch
        {
            return null;
        }
    }
}
