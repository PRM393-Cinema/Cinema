using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    public class GenerateSeatRequest
    {
        [Required(ErrorMessage = "RoomId is required.")]
        public long RoomId { get; set; }

        [Required(ErrorMessage = "Rows is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "Rows must be greater than 0.")]
        public int Rows { get; set; }

        [Required(ErrorMessage = "SeatsPerRow is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "SeatsPerRow must be greater than 0.")]
        public int SeatsPerRow { get; set; }

        public string SeatType { get; set; } = null!;
    }
}
