using Microsoft.EntityFrameworkCore;
using ShowtimeService.Models;

namespace ShowtimeService.Data;

public partial class ShowtimeDbContext : DbContext
{
    public ShowtimeDbContext()
    {
    }

    public ShowtimeDbContext(DbContextOptions<ShowtimeDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Room> Rooms { get; set; }

    public virtual DbSet<Seat> Seats { get; set; }

    public virtual DbSet<Showtime> Showtimes { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            IConfiguration configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", true, true)
                .Build();

            string connectionString = configuration.GetConnectionString("ShowtimeDb");

            optionsBuilder.UseNpgsql(connectionString);
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Room>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("rooms_pkey");

            entity.ToTable("rooms");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");
            entity.Property(e => e.TotalSeats).HasColumnName("total_seats");
        });

        modelBuilder.Entity<Seat>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("seats_pkey");

            entity.ToTable("seats");

            entity.HasIndex(e => new { e.RoomId, e.SeatRow, e.SeatNumber }, "uq_seat").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.RoomId).HasColumnName("room_id");
            entity.Property(e => e.SeatNumber).HasColumnName("seat_number");
            entity.Property(e => e.SeatRow)
                .HasMaxLength(5)
                .HasColumnName("seat_row");
            entity.Property(e => e.SeatType)
                .HasMaxLength(20)
                .HasDefaultValueSql("'NORMAL'::character varying")
                .HasColumnName("seat_type");

            entity.HasOne(d => d.Room).WithMany(p => p.Seats)
                .HasForeignKey(d => d.RoomId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("seats_room_id_fkey");
        });

        modelBuilder.Entity<Showtime>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("showtimes_pkey");

            entity.ToTable("showtimes");

            entity.HasIndex(e => e.MovieId, "idx_showtime_movie");

            entity.HasIndex(e => e.StartTime, "idx_showtime_start");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.EndTime)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("end_time");
            entity.Property(e => e.MovieId).HasColumnName("movie_id");
            entity.Property(e => e.Price)
                .HasPrecision(10, 2)
                .HasColumnName("price");
            entity.Property(e => e.RoomId).HasColumnName("room_id");
            entity.Property(e => e.StartTime)
                .HasColumnType("timestamp without time zone")
                .HasColumnName("start_time");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .HasDefaultValueSql("'OPEN'::character varying")
                .HasColumnName("status");

            entity.HasOne(d => d.Room).WithMany(p => p.Showtimes)
                .HasForeignKey(d => d.RoomId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("showtimes_room_id_fkey");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
