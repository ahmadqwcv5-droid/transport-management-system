using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Tracking;

/// <summary>
/// Explicit current-position projection. History remains immutable in truck_positions;
/// this row advances only under the ingestion chronology policy.
/// </summary>
public sealed class TruckCurrentPosition : Entity, ITenantOwned
{
    private TruckCurrentPosition() { }

    public TruckCurrentPosition(Guid companyId, TruckPosition position, DateTimeOffset now)
        : base(position.TruckId, now)
    {
        CompanyId = companyId;
        TruckId = position.TruckId;
        Advance(position, now);
    }

    public Guid CompanyId { get; private set; }
    public Guid TruckId { get; private set; }
    public Guid PositionId { get; private set; }
    public DateTimeOffset RecordedAt { get; private set; }
    public Guid? TrackingRunId { get; private set; }

    public void Advance(TruckPosition position, DateTimeOffset now)
    {
        if (position.CompanyId != CompanyId || position.TruckId != TruckId)
            throw new DomainRuleException("Current position projection scope does not match the position.", "POSITION_SCOPE_MISMATCH");
        PositionId = position.Id;
        RecordedAt = position.RecordedAt;
        TrackingRunId = position.TrackingRunId;
        Touch(now);
    }
}
