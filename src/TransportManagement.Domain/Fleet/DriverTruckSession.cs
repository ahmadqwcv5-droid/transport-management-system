using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class DriverTruckSession : Entity, ITenantOwned
{
    private DriverTruckSession() { }

    public DriverTruckSession(Guid id, Guid companyId, Guid driverId, Guid truckId,
        Guid tripId, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        DriverId = driverId;
        TruckId = truckId;
        StartedFromTripId = tripId;
        LastTripId = tripId;
        StartedAt = now;
    }

    public Guid CompanyId { get; private set; }
    public Guid DriverId { get; private set; }
    public Guid TruckId { get; private set; }
    public Guid StartedFromTripId { get; private set; }
    public Guid LastTripId { get; private set; }
    public DateTimeOffset StartedAt { get; private set; }
    public DateTimeOffset? EndedAt { get; private set; }
    public string? EndReason { get; private set; }
    public long Version { get; private set; }
    public bool IsActive => EndedAt is null;

    public void LinkTrip(Guid tripId, DateTimeOffset now)
    {
        if (!IsActive) throw new DomainRuleException("The vehicle session has ended.");
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
