using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    public class RoomRequest
    {
        [Required(ErrorMessage = "Room name is required.")]
        public string Name { get; set; } = null!;

        [Required(ErrorMessage = "Total seats is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "Total seats must be greater than 0.")]
        public int TotalSeats { get; set; }

        [Required(ErrorMessage = "Rows is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "Rows must be greater than 0.")]
        public int Rows { get; set; }

        [Required(ErrorMessage = "Seats per row is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "Seats per row must be greater than 0.")]
        public int SeatsPerRow { get; set; }
    }
}
