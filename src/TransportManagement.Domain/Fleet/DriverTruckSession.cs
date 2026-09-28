using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class DriverTruckSession : Entity, ITenantOwned
{
    private DriverTruckSession() { }

    public DriverTruckSession(Guid id, Guid companyId, Guid driverId, Guid truckId,
        Guid? tripId, string source, Guid? initiatedByAccountId,
        Guid? approvedByAccountId, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        DriverId = driverId;
        TruckId = truckId;
        StartedFromTripId = tripId;
        LastTripId = tripId;
        Source = source;
        InitiatedByAccountId = initiatedByAccountId;
        ApprovedByAccountId = approvedByAccountId;
        StartedAt = now;
    }

    public DriverTruckSession(Guid id, Guid companyId, Guid driverId, Guid truckId,
        Guid tripId, DateTimeOffset now)
        : this(id, companyId, driverId, truckId, tripId,
            "TripAssignment", null, null, now) { }

    public Guid CompanyId { get; private set; }
    public Guid DriverId { get; private set; }
    public Guid TruckId { get; private set; }
    public Guid? StartedFromTripId { get; private set; }
    public Guid? LastTripId { get; private set; }
    public string Source { get; private set; } = string.Empty;
    public Guid? InitiatedByAccountId { get; private set; }
    public Guid? ApprovedByAccountId { get; private set; }
    public DateTimeOffset StartedAt { get; private set; }
    public DateTimeOffset? EndedAt { get; private set; }
    public string? EndReason { get; private set; }
    public long Version { get; private set; }
    public bool IsActive => EndedAt is null;

    public void LinkTrip(Guid tripId, DateTimeOffset now)
    {
        if (!IsActive) throw new DomainRuleException("The vehicle session has ended.");
        StartedFromTripId ??= tripId;
        LastTripId = tripId;
        Version++;
        Touch(now);
    }

    public void End(string reason, DateTimeOffset now)
    {
        if (!IsActive) return;
        EndReason = string.IsNullOrWhiteSpace(reason) ? "DriverEnded" : reason.Trim();
        EndedAt = now;
        Version++;
        Touch(now);
    }
}
