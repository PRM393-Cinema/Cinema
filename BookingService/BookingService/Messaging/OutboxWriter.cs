using System.Text.Json;
using BookingService.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace BookingService.Messaging
{
    // Transactional outbox (BR-11): event được ghi vào bảng outbox_messages của cùng database,
    // lưu cùng lần SaveChanges / transaction với thay đổi nghiệp vụ. Dữ liệu rollback thì event cũng mất,
    // dữ liệu commit thì event chắc chắn được gửi (OutboxPublisherWorker gửi lên RabbitMQ sau đó).
    public sealed class OutboxWriter<TContext> where TContext : DbContext
    {
        private readonly TContext _context;

        public OutboxWriter(TContext context)
        {
            _context = context;
        }

        public void Add(string eventType, object data)
        {
            var eventId = Guid.NewGuid().ToString();
            var now = DateTime.Now;

            var payload = JsonSerializer.Serialize(
                new
                {
                    eventId,
                    eventType,
                    occurredAt = now,
                    data
                },
                MessagingJson.Options);

            _context.Set<OutboxMessage>().Add(new OutboxMessage
            {
                EventId = eventId,
                EventType = eventType,
                Payload = payload,
                CreatedAt = now
            });
        }

        // Transaction trên database chứa outbox: dùng khi event cần id vừa sinh (lưu 2 lần trong một transaction)
        public Task<IDbContextTransaction> BeginTransactionAsync()
        {
            return _context.Database.BeginTransactionAsync();
        }

        public Task SaveChangesAsync()
        {
            return _context.SaveChangesAsync();
        }
    }
}
