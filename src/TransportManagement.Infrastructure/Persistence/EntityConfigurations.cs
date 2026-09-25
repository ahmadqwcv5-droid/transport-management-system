using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class CompanyConfiguration : IEntityTypeConfiguration<Company>
{
    public void Configure(EntityTypeBuilder<Company> builder)
    {
        builder.ToTable("companies");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Slug).HasMaxLength(100).IsRequired();
        builder.HasIndex(x => x.Slug).IsUnique();
    }
}

internal sealed class TruckPositionConfiguration : IEntityTypeConfiguration<TruckPosition>
{
    public void Configure(EntityTypeBuilder<TruckPosition> builder)
    {
        builder.ToTable("truck_positions");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Latitude).HasPrecision(9, 6);
        builder.Property(x => x.Longitude).HasPrecision(9, 6);
        builder.Property(x => x.Speed).HasPrecision(8, 2);
        builder.Property(x => x.Heading).HasPrecision(6, 2);
        builder.Property(x => x.Source).HasMaxLength(50).IsRequired();
        builder.Property(x => x.MovementPhase).HasConversion<string>().HasMaxLength(30);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.TruckId, x.RecordedAt });
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.RecordedAt });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Trip>().WithMany().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TripRoutePlan>().WithMany().HasForeignKey(x => x.RoutePlanId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TripRepositioningPlan>().WithMany().HasForeignKey(x => x.RepositioningPlanId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Email).HasMaxLength(320).IsRequired();
        builder.Property(x => x.DisplayName).HasMaxLength(200).IsRequired();
        builder.Property(x => x.PasswordHash).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Role).HasMaxLength(50).IsRequired();
        builder.Property(x => x.PreferredLocale).HasMaxLength(5).HasDefaultValue("en").IsRequired();
        builder.Property(x => x.NotificationSoundsEnabled).HasDefaultValue(true).IsRequired();
        // Email is the login identifier and must therefore be globally unambiguous.
        builder.HasIndex(x => x.Email).IsUnique();
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class CompanyUserEventConfiguration : IEntityTypeConfiguration<CompanyUserEvent>
{
    public void Configure(EntityTypeBuilder<CompanyUserEvent> builder)
    {
        builder.ToTable("company_user_events");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EventCode).HasMaxLength(80).IsRequired();
        builder.Property(x => x.Metadata).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.SubjectUserId, x.CreatedAt });
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.SubjectUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("refresh_tokens");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
        builder.HasIndex(x => x.TokenHash).IsUnique();
        builder.HasIndex(x => new { x.UserId, x.ExpiresAt });
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class ClientConfiguration : IEntityTypeConfiguration<Client>
{
    public void Configure(EntityTypeBuilder<Client> builder)
    {
        builder.ToTable("clients");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.LegalName).HasMaxLength(200);
        builder.Property(x => x.ContactPerson).HasMaxLength(200);
        builder.Property(x => x.Phone).HasMaxLength(50);
        builder.Property(x => x.Email).HasMaxLength(320);
        builder.Property(x => x.Address).HasMaxLength(500);
        builder.Property(x => x.Notes).HasMaxLength(2000);
        builder.Property(x => x.LifecycleStatus).HasConversion<string>().HasMaxLength(20);
        builder.Ignore(x => x.IsActive);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.Name });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class ClientContactConfiguration : IEntityTypeConfiguration<ClientContact>
{
    public void Configure(EntityTypeBuilder<ClientContact> builder)
    {
        builder.ToTable("client_contacts");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.JobTitle).HasMaxLength(150);
        builder.Property(x => x.Phone).HasMaxLength(50);
        builder.Property(x => x.WhatsApp).HasMaxLength(50);
        builder.Property(x => x.Email).HasMaxLength(320);
        builder.Property(x => x.Notes).HasMaxLength(1000);
        builder.HasIndex(x => new { x.CompanyId, x.ClientId });
        builder.HasIndex(x => new { x.CompanyId, x.ClientId, x.IsPrimary })
            .IsUnique().HasFilter("\"IsPrimary\" = TRUE");
        builder.HasOne<Client>().WithMany().HasForeignKey(x => x.ClientId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class ClientSiteConfiguration : IEntityTypeConfiguration<ClientSite>
{
    public void Configure(EntityTypeBuilder<ClientSite> builder)
    {
        builder.ToTable("client_sites");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Name).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Type).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.Address).HasMaxLength(500);
        builder.Property(x => x.Latitude).HasPrecision(9, 6);
        builder.Property(x => x.Longitude).HasPrecision(9, 6);
        builder.Property(x => x.ContactName).HasMaxLength(200);
        builder.Property(x => x.ContactPhone).HasMaxLength(50);
        builder.Property(x => x.Instructions).HasMaxLength(1000);
        builder.HasIndex(x => new { x.CompanyId, x.ClientId, x.IsActive });
        builder.HasOne<Client>().WithMany().HasForeignKey(x => x.ClientId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class ClientEventConfiguration : IEntityTypeConfiguration<ClientEvent>
{
    public void Configure(EntityTypeBuilder<ClientEvent> builder)
    {
        builder.ToTable("client_events");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EventCode).HasMaxLength(80).IsRequired();
        builder.Property(x => x.Metadata).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.ClientId, x.CreatedAt });
        builder.HasOne<Client>().WithMany().HasForeignKey(x => x.ClientId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TruckConfiguration : IEntityTypeConfiguration<Truck>
{
    public void Configure(EntityTypeBuilder<Truck> builder)
    {
        builder.ToTable("trucks");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.PlateNumber).HasMaxLength(30).IsRequired();
        builder.Property(x => x.FleetCode).HasMaxLength(50);
        builder.Property(x => x.Vin).HasMaxLength(50);
        builder.Property(x => x.Make).HasMaxLength(100);
        builder.Property(x => x.Model).HasMaxLength(100);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.Type).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.FuelType).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.PayloadUnit).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.PayloadCapacity).HasPrecision(12, 2);
        builder.Property(x => x.OdometerKilometers).HasPrecision(14, 1);
        builder.Property(x => x.Notes).HasMaxLength(2000);
        builder.Ignore(x => x.IsActive);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.PlateNumber }).IsUnique();
        builder.HasIndex(x => new { x.CompanyId, x.Vin }).IsUnique()
            .HasFilter("\"Vin\" IS NOT NULL");
        builder.HasIndex(x => new { x.CompanyId, x.FleetCode }).IsUnique()
            .HasFilter("\"FleetCode\" IS NOT NULL");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DefaultDriverId).OnDelete(DeleteBehavior.SetNull);
    }
}

internal sealed class TruckEventConfiguration : IEntityTypeConfiguration<TruckEvent>
{
    public void Configure(EntityTypeBuilder<TruckEvent> builder)
    {
        builder.ToTable("truck_events");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EventCode).HasMaxLength(80).IsRequired();
        builder.Property(x => x.Metadata).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.TruckId, x.CreatedAt });
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class DriverConfiguration : IEntityTypeConfiguration<Driver>
{
    public void Configure(EntityTypeBuilder<Driver> builder)
    {
        builder.ToTable("drivers");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.FullName).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Phone).HasMaxLength(50);
        builder.Property(x => x.LicenseNumber).HasMaxLength(100).IsRequired();
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.Notes).HasMaxLength(2000);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.LicenseNumber }).IsUnique();
        builder.HasIndex(x => x.UserId).IsUnique().HasFilter("\"UserId\" IS NOT NULL");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithOne().HasForeignKey<Driver>(x => x.UserId).OnDelete(DeleteBehavior.SetNull);
    }
}

internal sealed class TripConfiguration : IEntityTypeConfiguration<Trip>
{
    private const string ReservedStatuses = "\"Status\" IN ('Assigned', 'EnRouteToPickup', 'AtPickup', 'Started', 'InTransit', 'AtDelivery', 'Delivered')";

    public void Configure(EntityTypeBuilder<Trip> builder)
    {
        builder.ToTable("trips");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.TripNumber).HasMaxLength(20).IsRequired();
        builder.Property(x => x.Origin).HasMaxLength(300);
        builder.Property(x => x.Destination).HasMaxLength(300);
        builder.Property(x => x.CargoDescription).HasMaxLength(1000).IsRequired();
        builder.Property(x => x.Price).HasPrecision(18, 2);
        builder.Property(x => x.Notes).HasMaxLength(2000);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.CancellationReason).HasMaxLength(500);
        builder.Property(x => x.Version).IsConcurrencyToken();
        builder.Ignore(x => x.ReservesResources);
        builder.Ignore(x => x.CurrentRepositioningPlan);
        builder.Ignore(x => x.IsArchived);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.TripNumber }).IsUnique();
        builder.HasIndex(x => new { x.CompanyId, x.Status });
        builder.HasIndex(x => new { x.CompanyId, x.PlannedStartAt });
        builder.HasIndex(x => new { x.CompanyId, x.TruckId })
            .IsUnique().HasFilter($"\"TruckId\" IS NOT NULL AND {ReservedStatuses}");
        builder.HasIndex(x => new { x.CompanyId, x.DriverId })
            .IsUnique().HasFilter($"\"DriverId\" IS NOT NULL AND {ReservedStatuses}");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Client>().WithMany().HasForeignKey(x => x.ClientId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DriverId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(x => x.Stops).WithOne().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(x => x.RoutePlan).WithOne().HasForeignKey<TripRoutePlan>(x => x.TripId).OnDelete(DeleteBehavior.Cascade);
        builder.HasMany(x => x.RepositioningPlans).WithOne().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Restrict);
        builder.HasMany(x => x.Events).WithOne().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class TripGeofenceObservationConfiguration : IEntityTypeConfiguration<TripGeofenceObservation>
{
    public void Configure(EntityTypeBuilder<TripGeofenceObservation> builder)
    {
        builder.ToTable("trip_geofence_observations");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Stage).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.RouteIdentity).HasMaxLength(100).IsRequired();
        builder.Property(x => x.Version).IsConcurrencyToken();
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.Stage, x.RouteIdentity }).IsUnique();
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Trip>().WithMany().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class OperationNotificationConfiguration : IEntityTypeConfiguration<OperationNotification>
{
    public void Configure(EntityTypeBuilder<OperationNotification> builder)
    {
        builder.ToTable("operation_notifications");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Type).HasMaxLength(80).IsRequired();
        builder.Property(x => x.Severity).HasMaxLength(20).IsRequired();
        builder.Property(x => x.EventKey).HasMaxLength(200).IsRequired();
        builder.Property(x => x.DataJson).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.EventKey }).IsUnique();
        builder.HasIndex(x => new { x.CompanyId, x.CreatedAt });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Trip>().WithMany().HasForeignKey(x => x.TripId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DriverId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ReadByUserId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TruckPhotoConfiguration : IEntityTypeConfiguration<TruckPhoto>
{
    public void Configure(EntityTypeBuilder<TruckPhoto> builder)
    {
        builder.ToTable("truck_photos");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.StorageKey).HasMaxLength(200).IsRequired();
        builder.Property(x => x.ContentType).HasMaxLength(50).IsRequired();
        builder.Property(x => x.Version).HasMaxLength(64).IsRequired();
        builder.HasIndex(x => new { x.CompanyId, x.TruckId }).IsUnique();
        builder.HasIndex(x => x.StorageKey).IsUnique();
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.UploadedByUserId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripNumberCounterConfiguration : IEntityTypeConfiguration<TripNumberCounter>
{
    public void Configure(EntityTypeBuilder<TripNumberCounter> builder)
    {
        builder.ToTable("trip_number_counters");
        builder.HasKey(x => new { x.CompanyId, x.Year });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripEventConfiguration : IEntityTypeConfiguration<TripEvent>
{
    public void Configure(EntityTypeBuilder<TripEvent> builder)
    {
        builder.ToTable("trip_events");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EventType).HasMaxLength(80).IsRequired();
        builder.Property(x => x.Source).HasMaxLength(20).IsRequired();
        builder.Property(x => x.Metadata).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.OccurredAt });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripRepositioningPlanConfiguration : IEntityTypeConfiguration<TripRepositioningPlan>
{
    public void Configure(EntityTypeBuilder<TripRepositioningPlan> builder)
    {
        builder.ToTable("trip_repositioning_plans");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.OriginLatitude).HasPrecision(9, 6);
        builder.Property(x => x.OriginLongitude).HasPrecision(9, 6);
        builder.Property(x => x.DestinationLatitude).HasPrecision(9, 6);
        builder.Property(x => x.DestinationLongitude).HasPrecision(9, 6);
        builder.Property(x => x.Geometry).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.GeometryFormat).HasMaxLength(50).IsRequired();
        builder.Property(x => x.DistanceMeters).HasPrecision(14, 2);
        builder.Property(x => x.ProviderName).HasMaxLength(100).IsRequired();
        builder.Property(x => x.RouteProfile).HasMaxLength(50).IsRequired();
        builder.Property(x => x.ProviderRouteId).HasMaxLength(300);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(30);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.Status });
        builder.HasIndex(x => new { x.CompanyId, x.TruckId, x.Status });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TruckPosition>().WithMany().HasForeignKey(x => x.SourceTruckPositionId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripStopConfiguration : IEntityTypeConfiguration<TripStop>
{
    public void Configure(EntityTypeBuilder<TripStop> builder)
    {
        builder.ToTable("trip_stops");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Type).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.Name).HasMaxLength(300).IsRequired();
        builder.Property(x => x.Address).HasMaxLength(500);
        builder.Property(x => x.Latitude).HasPrecision(9, 6);
        builder.Property(x => x.Longitude).HasPrecision(9, 6);
        builder.Ignore(x => x.HasCoordinates);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.Sequence }).IsUnique();
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripRoutePlanConfiguration : IEntityTypeConfiguration<TripRoutePlan>
{
    public void Configure(EntityTypeBuilder<TripRoutePlan> builder)
    {
        builder.ToTable("trip_route_plans");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Geometry).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.GeometryFormat).HasMaxLength(50).IsRequired();
        builder.Property(x => x.DistanceMeters).HasPrecision(14, 2);
        builder.Property(x => x.ProviderName).HasMaxLength(100).IsRequired();
        builder.Property(x => x.RouteProfile).HasMaxLength(50).IsRequired();
        builder.Property(x => x.StopsFingerprint).HasMaxLength(64).IsRequired();
        builder.Property(x => x.ProviderRouteId).HasMaxLength(300);
        builder.Property(x => x.Warnings).HasMaxLength(2000);
        builder.HasIndex(x => x.CompanyId);
        builder.HasIndex(x => x.TripId).IsUnique();
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId).OnDelete(DeleteBehavior.Restrict);
    }
}
