using System.ComponentModel.DataAnnotations;

namespace ShowtimeService.DTOs.Request
{
    public class UpdateSeatTypeRequest
    {
        [Required(ErrorMessage = "SeatIds is required.")]
        public List<long> SeatIds { get; set; } = new List<long>();

        [Required(ErrorMessage = "SeatType is required.")]
        public string SeatType { get; set; } = string.Empty;
    }
}
