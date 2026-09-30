using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    public class SeatRequest
    {
        [Required(ErrorMessage = "Seat id is required")]
        public long SeatId { get; set; }

        ///
        /// không để price ra bên ngoài vì client có thể sửa
        ///

        //[Required(ErrorMessage = "Seat label is required")]
        //[MinLength(1, ErrorMessage = "Seat label is required")]
        //public string? SeatLabel { get; set; }

        //[Required(ErrorMessage = "Price is required")]
        //[Range(
        //    0.01,
        //    double.MaxValue,
        //    ErrorMessage = "Price must be greater than 0"
        //)]
        //public decimal? Price { get; set; }
    }
}
