using System;
using System.Collections.Generic;
using BookingService.Models;
using Microsoft.EntityFrameworkCore;

namespace BookingService.Data;

public partial class BookingDbContext : DbContext
{
    public BookingDbContext()
    {
    }

    public BookingDbContext(DbContextOptions<BookingDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Booking> Bookings { get; set; }

    public virtual DbSet<BookingSeat> BookingSeats { get; set; }

    public virtual DbSet<SeatReservation> SeatReservations { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Booking>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("bookings_pkey");

            entity.ToTable("bookings");

            entity.HasIndex(e => e.BookingCode, "bookings_booking_code_key").IsUnique();

            entity.HasIndex(e => e.ShowtimeId, "idx_booking_showtime");

            entity.HasIndex(e => e.UserId, "idx_booking_user");

            entity.HasIndex(e => new { e.Status, e.ExpiresAt }, "idx_booking_status_expires");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.BookingCode)
                .HasMaxLength(40)
                .HasColumnName("booking_code");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
            entity.Property(e => e.CustomerEmail)
                .HasMaxLength(150)
                .HasColumnName("customer_email");
            entity.Property(e => e.ExpiresAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("expires_at");
            entity.Property(e => e.MovieTitle)
                .HasMaxLength(200)
                .HasColumnName("movie_title");
            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
            entity.Property(e => e.ShowTime)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("show_time");
            entity.Property(e => e.ShowtimeId).HasColumnName("showtime_id");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'PENDING'::character varying")
                .HasColumnName("status");
            entity.Property(e => e.TotalAmount)
                .HasPrecision(10, 2)
                .HasColumnName("total_amount");
            entity.Property(e => e.UserId).HasColumnName("user_id");
        });

        modelBuilder.Entity<BookingSeat>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("booking_seats_pkey");

            entity.ToTable("booking_seats");
            entity.HasIndex(e => new { e.BookingId, e.SeatId })
                 .IsUnique()
                 .HasDatabaseName("ix_booking_seats_booking_id_seat_id");
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.BookingId).HasColumnName("booking_id");
            entity.Property(e => e.Price)
                .HasPrecision(10, 2)
                .HasColumnName("price");
            entity.Property(e => e.SeatId).HasColumnName("seat_id");
            entity.Property(e => e.SeatLabel)
                .HasMaxLength(10)
                .HasColumnName("seat_label");

            entity.HasOne(d => d.Booking).WithMany(p => p.BookingSeats)
                .HasForeignKey(d => d.BookingId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("booking_seats_booking_id_fkey");
        });

        modelBuilder.Entity<SeatReservation>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("seat_reservations_pkey");

            entity.ToTable("seat_reservations");

            entity.HasIndex(e => e.BookingId, "idx_resv_booking");

            entity.HasIndex(e => new { e.ShowtimeId, e.SeatId }, "uq_seat_per_showtime").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.BookingId).HasColumnName("booking_id");
            entity.Property(e => e.HeldUntil)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("held_until");
            entity.Property(e => e.SeatId).HasColumnName("seat_id");
            entity.Property(e => e.ShowtimeId).HasColumnName("showtime_id");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasColumnName("status");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
