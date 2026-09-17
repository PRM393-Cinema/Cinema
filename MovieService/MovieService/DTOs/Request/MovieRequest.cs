using System.ComponentModel.DataAnnotations;

namespace MovieService.DTOs.Request
{
    public class MovieRequest
    {
        [Required(ErrorMessage = "Title is required")]
        public string? Title { get; set; }

        public string? Description { get; set; }

        [Required(ErrorMessage = "Duration is required")]
        [Range(1, int.MaxValue, ErrorMessage = "Duration must be greater than 0")]
        public int DurationMinutes { get; set; } = 60;

        public string? Genre { get; set; }

        public string? Language { get; set; }

        public DateTime ReleaseDate { get; set; } = DateTime.Now;

        public string? PosterUrl { get; set; }

        public string? TrailerUrl { get; set; }     
    }
}
