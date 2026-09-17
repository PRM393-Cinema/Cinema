using System.Runtime.InteropServices;

namespace MovieService.DTOs.Response
{
    public class MovieResponse
    {
        public long Id { get; set; }
        public string? Title { get; set; }
        public string? Description { get; set; }
        public int DurationMinutes { get; set; }
        public string? Genre { get; set; }
        public string? Language { get; set; }
        public DateOnly ReleaseDate { get; set; }
        public string? PosterUrl { get; set; }
        public string? TrailerUrl { get; set; }
        public string? Status { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
