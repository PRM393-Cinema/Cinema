using System;
using System.Collections.Generic;

namespace MovieService.Models;

public partial class Movie
{
    public long Id { get; set; }

    public string Title { get; set; } = null!;

    public string? Description { get; set; }

    public int DurationMinutes { get; set; }

    public string? Genre { get; set; }

    public string? Language { get; set; }

    public DateOnly? ReleaseDate { get; set; }

    public string? PosterUrl { get; set; }

    public string Status { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public string? TrailerUrl { get; set; }
}
