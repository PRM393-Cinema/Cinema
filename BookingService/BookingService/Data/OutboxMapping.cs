using BookingService.Models;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Data;

// Bảng outbox_messages có trong cinema_booking_db và cinema_payment_db (cùng cấu trúc)
public static class OutboxMapping
{
    public static void MapOutbox(this ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<OutboxMessage>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("outbox_messages_pkey");

            entity.ToTable("outbox_messages");

            entity.HasIndex(e => e.EventId, "outbox_messages_event_id_key").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EventId)
                .HasMaxLength(36)
                .HasColumnName("event_id");
            entity.Property(e => e.EventType)
                .HasMaxLength(100)
                .HasColumnName("event_type");
            entity.Property(e => e.Payload).HasColumnName("payload");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
            entity.Property(e => e.PublishedAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("published_at");
            entity.Property(e => e.Attempts).HasColumnName("attempts");
            entity.Property(e => e.LastError)
                .HasMaxLength(1000)
                .HasColumnName("last_error");
        });
    }
}

public partial class BookingDbContext
{
    public virtual DbSet<OutboxMessage> OutboxMessages { get; set; }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        modelBuilder.MapOutbox();
    }
}

public partial class PaymentDbContext
{
    public virtual DbSet<OutboxMessage> OutboxMessages { get; set; }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        modelBuilder.MapOutbox();
    }
}
