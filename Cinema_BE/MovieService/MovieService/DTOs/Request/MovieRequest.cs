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
        public string? PreviewUrl { get; set; }

        // Phân loại phim: P (mọi độ tuổi), K (dưới 13 tuổi xem cùng cha mẹ), T13, T16, T18.
        // Thêm phim mà bỏ trống thì là P; sửa phim mà bỏ trống thì giữ nguyên
        public string? AgeRating { get; set; }

        [MaxLength(150, ErrorMessage = "Director must be at most 150 characters")]
        public string? Director { get; set; }

        // Diễn viên chính, cách nhau dấu phẩy
        [MaxLength(500, ErrorMessage = "Cast must be at most 500 characters")]
        public string? Cast { get; set; }

        // Chỉ dùng khi sửa phim: ACTIVE (đang chiếu) / INACTIVE (ngừng chiếu). Bỏ trống thì giữ nguyên
        public string? Status { get; set; }
    }
}
