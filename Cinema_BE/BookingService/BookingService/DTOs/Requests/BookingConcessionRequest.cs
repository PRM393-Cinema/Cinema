using System.ComponentModel.DataAnnotations;

namespace BookingService.DTOs.Requests
{
    // Một món bắp nước khách chọn kèm vé; giá do server lấy từ menu
    public class BookingConcessionRequest
    {
        [Required(ErrorMessage = "Item id is required")]
        public long ItemId { get; set; }

        [Range(1, 20, ErrorMessage = "Quantity must be between 1 and 20")]
        public int Quantity { get; set; } = 1;
    }
}
