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

    public virtual DbSet<ConcessionItem> ConcessionItems { get; set; }

    public virtual DbSet<BookingConcession> BookingConcessions { get; set; }

    public virtual DbSet<Promotion> Promotions { get; set; }

    public virtual DbSet<MovieReview> MovieReviews { get; set; }

    public virtual DbSet<LoyaltyAccount> LoyaltyAccounts { get; set; }

    public virtual DbSet<LoyaltyTransaction> LoyaltyTransactions { get; set; }

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
            entity.Property(e => e.CustomerPhone)
                .HasMaxLength(20)
                .HasColumnName("customer_phone");
            entity.Property(e => e.ExpiresAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("expires_at");
            entity.Property(e => e.CheckedInAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("checked_in_at");
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
            entity.Property(e => e.ConcessionsAmount)
                .HasPrecision(10, 2)
                .HasDefaultValue(0m)
                .HasColumnName("concessions_amount");
            entity.Property(e => e.DiscountAmount)
                .HasPrecision(10, 2)
                .HasDefaultValue(0m)
                .HasColumnName("discount_amount");
            entity.Property(e => e.PromotionId).HasColumnName("promotion_id");
            entity.Property(e => e.PromotionCode).HasMaxLength(30).HasColumnName("promotion_code");
            entity.Property(e => e.PromotionName).HasMaxLength(100).HasColumnName("promotion_name");
            entity.Property(e => e.PointsUsed).HasDefaultValue(0).HasColumnName("points_used");
            entity.Property(e => e.PointsDiscount)
                .HasPrecision(10, 2)
                .HasDefaultValue(0m)
                .HasColumnName("points_discount");
            entity.Property(e => e.PointsEarned).HasDefaultValue(0).HasColumnName("points_earned");
            entity.Property(e => e.RemindedAt)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("reminded_at");
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

        modelBuilder.Entity<ConcessionItem>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("concession_items_pkey");
            entity.ToTable("concession_items");
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name).HasMaxLength(100).HasColumnName("name");
            entity.Property(e => e.Description).HasMaxLength(255).HasColumnName("description");
            entity.Property(e => e.Price).HasPrecision(10, 2).HasColumnName("price");
            entity.Property(e => e.ImageUrl).HasMaxLength(500).HasColumnName("image_url");
            entity.Property(e => e.Active).HasDefaultValue(true).HasColumnName("active");
            entity.Property(e => e.SortOrder).HasDefaultValue(0).HasColumnName("sort_order");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
        });

        modelBuilder.Entity<LoyaltyAccount>(entity =>
        {
            entity.HasKey(e => e.UserId).HasName("loyalty_accounts_pkey");
            entity.ToTable("loyalty_accounts");
            entity.Property(e => e.UserId).ValueGeneratedNever().HasColumnName("user_id");
            entity.Property(e => e.Points).HasDefaultValue(0).HasColumnName("points");
            entity.Property(e => e.LifetimeSpend).HasPrecision(14, 2).HasDefaultValue(0m).HasColumnName("lifetime_spend");
            entity.Property(e => e.Tier).HasMaxLength(10).HasDefaultValue("MEMBER").HasColumnName("tier");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("updated_at");
        });

        modelBuilder.Entity<LoyaltyTransaction>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("loyalty_transactions_pkey");
            entity.ToTable("loyalty_transactions");
            entity.HasIndex(e => new { e.UserId, e.CreatedAt }, "idx_loyalty_transactions_user");
            entity.HasIndex(e => e.BookingId, "idx_loyalty_transactions_booking");
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.BookingId).HasColumnName("booking_id");
            entity.Property(e => e.Type).HasMaxLength(10).HasColumnName("type");
            entity.Property(e => e.Points).HasColumnName("points");
            entity.Property(e => e.SpendChange).HasPrecision(14, 2).HasDefaultValue(0m).HasColumnName("spend_change");
            entity.Property(e => e.Note).HasMaxLength(255).HasColumnName("note");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
        });

        modelBuilder.Entity<MovieReview>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("movie_reviews_pkey");
            entity.ToTable("movie_reviews");
            entity.HasIndex(e => new { e.UserId, e.MovieId }, "movie_reviews_user_movie_key").IsUnique();
            entity.HasIndex(e => new { e.MovieId, e.CreatedAt }, "idx_movie_reviews_movie");
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.MovieId).HasColumnName("movie_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.BookingId).HasColumnName("booking_id");
            entity.Property(e => e.ReviewerName).HasMaxLength(150).HasColumnName("reviewer_name");
            entity.Property(e => e.Rating).HasColumnName("rating");
            entity.Property(e => e.Comment).HasMaxLength(1000).HasColumnName("comment");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("updated_at");
        });

        modelBuilder.Entity<Promotion>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("promotions_pkey");
            entity.ToTable("promotions");
            entity.HasIndex(e => e.Code, "promotions_code_key").IsUnique();
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Code).HasMaxLength(30).HasColumnName("code");
            entity.Property(e => e.Name).HasMaxLength(100).HasColumnName("name");
            entity.Property(e => e.Description).HasMaxLength(255).HasColumnName("description");
            entity.Property(e => e.DiscountType).HasMaxLength(10).HasColumnName("discount_type");
            entity.Property(e => e.DiscountValue).HasPrecision(10, 2).HasColumnName("discount_value");
            entity.Property(e => e.MaxDiscount).HasPrecision(10, 2).HasColumnName("max_discount");
            entity.Property(e => e.MinTickets).HasDefaultValue(1).HasColumnName("min_tickets");
            entity.Property(e => e.DaysOfWeek).HasMaxLength(20).HasColumnName("days_of_week");
            entity.Property(e => e.StartsAt).HasColumnType("timestamp without time zone").HasColumnName("starts_at");
            entity.Property(e => e.EndsAt).HasColumnType("timestamp without time zone").HasColumnName("ends_at");
            entity.Property(e => e.UsageLimit).HasColumnName("usage_limit");
            entity.Property(e => e.UsedCount).HasDefaultValue(0).HasColumnName("used_count");
            entity.Property(e => e.Active).HasDefaultValue(true).HasColumnName("active");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("CURRENT_TIMESTAMP")
                .HasColumnType("timestamp without time zone")
                .HasColumnName("created_at");
        });

        modelBuilder.Entity<BookingConcession>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("booking_concessions_pkey");
            entity.ToTable("booking_concessions");
            entity.HasIndex(e => e.BookingId, "idx_booking_concessions_booking");
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.BookingId).HasColumnName("booking_id");
            entity.Property(e => e.ItemId).HasColumnName("item_id");
            entity.Property(e => e.ItemName).HasMaxLength(100).HasColumnName("item_name");
            entity.Property(e => e.UnitPrice).HasPrecision(10, 2).HasColumnName("unit_price");
            entity.Property(e => e.Quantity).HasColumnName("quantity");

            entity.HasOne(d => d.Booking).WithMany(p => p.Concessions)
                .HasForeignKey(d => d.BookingId)
                .OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("booking_concessions_booking_id_fkey");
            entity.HasOne<ConcessionItem>().WithMany()
                .HasForeignKey(d => d.ItemId)
                .OnDelete(DeleteBehavior.Restrict)
                .HasConstraintName("booking_concessions_item_id_fkey");
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
        modelBuilder.Entity<MemberGift>(e => {
            e.ToTable("member_gifts"); e.HasKey(x=>x.UserId);
            e.Property(x=>x.UserId).HasColumnName("user_id");
            e.Property(x=>x.Tier).HasColumnName("tier");
            e.Property(x=>x.RenewsAt).HasColumnName("renews_at").HasColumnType("timestamp without time zone");
            e.Property(x=>x.Tickets).HasColumnName("tickets"); e.Property(x=>x.Combos).HasColumnName("combos");
        });
        modelBuilder.Entity<MemberGiftUse>(e => {
            e.ToTable("member_gift_uses"); e.HasKey(x=>x.BookingId);
            e.Property(x=>x.BookingId).HasColumnName("booking_id"); e.Property(x=>x.UserId).HasColumnName("user_id");
            e.Property(x=>x.RenewsAt).HasColumnName("renews_at").HasColumnType("timestamp without time zone");
            e.Property(x=>x.Tickets).HasColumnName("tickets"); e.Property(x=>x.Combos).HasColumnName("combos");
            e.Property(x=>x.Discount).HasColumnName("discount").HasPrecision(12,2);
        });
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
