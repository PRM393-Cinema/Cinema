using System.Net;
using System.Net.Http.Json;
using BookingService.Clients.Interfaces;
using BookingService.Exceptions;
using Microsoft.AspNetCore.Mvc;
using Polly.CircuitBreaker;
using Polly.Timeout;

namespace BookingService.Clients.Implementations;

public class ShowtimeClient : IShowtimeClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ShowtimeClient> _logger;

    public ShowtimeClient(HttpClient httpClient, ILogger<ShowtimeClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<List<ShowtimeSeatInfo>> GetSeatsAsync(
        long showtimeId,
        List<long> seatIds)
    {
        var response = await SendAsync(() => _httpClient.PostAsJsonAsync(
            $"api/showtimes/{showtimeId}/seats",
            seatIds));

        if (response.IsSuccessStatusCode)
        {
            var result =
                await response.Content
                    .ReadFromJsonAsync<List<ShowtimeSeatInfo>>();

            return result ?? new List<ShowtimeSeatInfo>();
        }

        throw await ToExceptionAsync(
            response,
            $"Showtime with ID {showtimeId} was not found.",
            "One or more selected seats are invalid for this showtime.");
    }

    public async Task<ShowtimeInfo> GetShowtimeAsync(long showtimeId)
    {
        var response = await SendAsync(() => _httpClient.GetAsync(
            $"api/showtimes/{showtimeId}"));

        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<ShowtimeInfo>()
                ?? throw new ExternalServiceException(
                    $"Showtime service returned no data for showtime {showtimeId}.");
        }

        throw await ToExceptionAsync(
            response,
            $"Showtime with ID {showtimeId} was not found.",
            $"Showtime with ID {showtimeId} is invalid.");
    }

    public async Task<string?> GetMovieTitleAsync(long movieId)
    {
        try
        {
            var response = await _httpClient.GetAsync($"api/v1/movies/{movieId}");

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning(
                    "Could not load title of movie {MovieId}: status {StatusCode}.",
                    movieId,
                    (int)response.StatusCode);
                return null;
            }

            var movie = await response.Content.ReadFromJsonAsync<MovieTitleResponse>();
            return string.IsNullOrWhiteSpace(movie?.Title) ? null : movie.Title.Trim();
        }
        catch (System.Exception ex)
        {
            _logger.LogWarning(ex, "Could not load title of movie {MovieId}.", movieId);
            return null;
        }
    }

    private static async Task<HttpResponseMessage> SendAsync(
        Func<Task<HttpResponseMessage>> send)
    {
        try
        {
            return await send();
        }
        // Đã retry mà vẫn lỗi kết nối / quá thời gian chờ, hoặc circuit breaker đang mở
        catch (System.Exception ex) when (ex is HttpRequestException or TaskCanceledException
                                              or TimeoutRejectedException or BrokenCircuitException)
        {
            throw new ServiceUnavailableException(
                "Showtime service is temporarily unavailable. Please try again later.", ex);
        }
    }

    // MovieService trả ProblemDetails: chuyển lỗi nghiệp vụ về đúng mã thay vì 500.
    private static async Task<System.Exception> ToExceptionAsync(
        HttpResponseMessage response,
        string notFoundMessage,
        string badRequestMessage)
    {
        var detail = await ReadErrorDetailAsync(response);

        return response.StatusCode switch
        {
            HttpStatusCode.NotFound => new NotFoundException(detail ?? notFoundMessage),
            HttpStatusCode.BadRequest => new BusinessException(detail ?? badRequestMessage),
            HttpStatusCode.Conflict => new ConflictException(detail ?? badRequestMessage),
            HttpStatusCode.ServiceUnavailable => new ServiceUnavailableException(
                "Showtime service is temporarily unavailable. Please try again later."),
            HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden => new ExternalServiceException(
                $"Showtime service rejected the request ({(int)response.StatusCode}). " +
                "Check that Jwt:SecretKey is the same in MovieService and BookingService."),
            _ => new ExternalServiceException(
                $"Showtime service returned status {(int)response.StatusCode}.")
        };
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

    private sealed class MovieTitleResponse
    {
        public string? Title { get; set; }
    }
}
