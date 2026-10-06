namespace MovieService.Messaging;

// Event chờ gửi lên RabbitMQ, ghi cùng transaction với dữ liệu nghiệp vụ (bảng outbox_messages)
public partial class OutboxMessage
{
    public long Id { get; set; }

    public string EventId { get; set; } = null!;

    public string EventType { get; set; } = null!;

    public string Payload { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime? PublishedAt { get; set; }

    public int Attempts { get; set; }

    public string? LastError { get; set; }
}
