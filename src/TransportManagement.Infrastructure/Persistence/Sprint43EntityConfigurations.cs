using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TransportManagement.Domain.Companies;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Identity;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Infrastructure.Persistence;

internal sealed class CompanyMembershipConfiguration
    : IEntityTypeConfiguration<CompanyMembership>
{
    public void Configure(EntityTypeBuilder<CompanyMembership> builder)
    {
        builder.ToTable("company_memberships");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.Version).IsConcurrencyToken();
        builder.Ignore(x => x.IsActive);
        builder.HasIndex(x => new { x.CompanyId, x.AccountId }).IsUnique();
        builder.HasIndex(x => new { x.AccountId, x.Status });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.InvitedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class CompanyMembershipRoleConfiguration
    : IEntityTypeConfiguration<CompanyMembershipRole>
{
    public void Configure(EntityTypeBuilder<CompanyMembershipRole> builder)
    {
        builder.ToTable("company_membership_roles");
        builder.HasKey(x => new { x.MembershipId, x.Role });
        builder.Property(x => x.Role).HasMaxLength(50);
        builder.HasIndex(x => x.CompanyId);
        builder.HasOne<CompanyMembership>().WithMany()
            .HasForeignKey(x => x.MembershipId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class ExternalLoginConfiguration
    : IEntityTypeConfiguration<ExternalLogin>
{
    public void Configure(EntityTypeBuilder<ExternalLogin> builder)
    {
        builder.ToTable("external_logins");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Provider).HasMaxLength(40).IsRequired();
        builder.Property(x => x.ProviderSubject).HasMaxLength(255).IsRequired();
        builder.Property(x => x.EmailSnapshot).HasMaxLength(320).IsRequired();
        builder.HasIndex(x => new { x.Provider, x.ProviderSubject }).IsUnique();
        builder.HasIndex(x => new { x.AccountId, x.Provider }).IsUnique();
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

internal sealed class CompanyInvitationConfiguration
    : IEntityTypeConfiguration<CompanyInvitation>
{
    public void Configure(EntityTypeBuilder<CompanyInvitation> builder)
    {
        builder.ToTable("company_invitations");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Email).HasMaxLength(320).IsRequired();
        builder.Property(x => x.RolesJson).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        builder.HasIndex(x => x.TokenHash).IsUnique();
        builder.HasIndex(x => new { x.CompanyId, x.Email, x.Status });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.InviterAccountId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AcceptedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class CompanyConnectionRequestConfiguration
    : IEntityTypeConfiguration<CompanyConnectionRequest>
{
    public void Configure(EntityTypeBuilder<CompanyConnectionRequest> builder)
    {
        builder.ToTable("company_connection_requests");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.RequestedRolesJson).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.ResolutionReason).HasMaxLength(1000);
        builder.HasIndex(x => new { x.CompanyId, x.AccountId, x.Status });
        builder.HasIndex(x => new { x.CompanyId, x.AccountId }).IsUnique()
            .HasFilter("\"Status\" = 'Pending'");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ResolvedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class IdentityAuditEventConfiguration
    : IEntityTypeConfiguration<IdentityAuditEvent>
{
    public void Configure(EntityTypeBuilder<IdentityAuditEvent> builder)
    {
        builder.ToTable("identity_audit_events");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EventCode).HasMaxLength(80).IsRequired();
        builder.Property(x => x.DataJson).HasColumnType("jsonb");
        builder.HasIndex(x => new { x.CompanyId, x.CreatedAt });
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AccountId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ActorAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TruckQrCredentialConfiguration
    : IEntityTypeConfiguration<TruckQrCredential>
{
    public void Configure(EntityTypeBuilder<TruckQrCredential> builder)
    {
        builder.ToTable("truck_qr_credentials");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.TokenHash).HasMaxLength(64).IsRequired();
        builder.Property(x => x.CodeHint).HasMaxLength(12).IsRequired();
        builder.Ignore(x => x.IsActive);
        builder.HasIndex(x => x.TokenHash).IsUnique();
        builder.HasIndex(x => new { x.CompanyId, x.TruckId }).IsUnique()
            .HasFilter("\"RevokedAt\" IS NULL");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId)
            .OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.GeneratedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.RevokedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripHandoverRequestConfiguration
    : IEntityTypeConfiguration<TripHandoverRequest>
{
    public void Configure(EntityTypeBuilder<TripHandoverRequest> builder)
    {
        builder.ToTable("trip_handover_requests");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(x => x.Reason).HasMaxLength(1000);
        builder.Property(x => x.ResolutionReason).HasMaxLength(1000);
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.Status });
        builder.HasIndex(x => new { x.CompanyId, x.TripId }).IsUnique()
            .HasFilter("\"Status\" = 'Pending'");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Trip>().WithMany().HasForeignKey(x => x.TripId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Truck>().WithMany().HasForeignKey(x => x.TruckId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.CurrentDriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.RequestingDriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.RequestedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ResolvedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

internal sealed class TripDriverParticipationConfiguration
    : IEntityTypeConfiguration<TripDriverParticipation>
{
    public void Configure(EntityTypeBuilder<TripDriverParticipation> builder)
    {
        builder.ToTable("trip_driver_participations");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Source).HasMaxLength(40).IsRequired();
        builder.Property(x => x.StartedPhase).HasConversion<string>().HasMaxLength(30);
        builder.Property(x => x.EndedPhase).HasConversion<string>().HasMaxLength(30);
        builder.Ignore(x => x.IsActive);
        builder.HasIndex(x => new { x.CompanyId, x.TripId, x.StartedAt });
        builder.HasIndex(x => new { x.CompanyId, x.TripId }).IsUnique()
            .HasFilter("\"EndedAt\" IS NULL");
        builder.HasOne<Company>().WithMany().HasForeignKey(x => x.CompanyId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Trip>().WithMany().HasForeignKey(x => x.TripId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Driver>().WithMany().HasForeignKey(x => x.DriverId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TripHandoverRequest>().WithMany()
            .HasForeignKey(x => x.HandoverRequestId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.AssignedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<User>().WithMany().HasForeignKey(x => x.ApprovedByAccountId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
