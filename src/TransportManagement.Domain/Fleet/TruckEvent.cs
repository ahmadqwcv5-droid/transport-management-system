using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Fleet;

public sealed class TruckEvent : Entity, ITenantOwned
{
    private TruckEvent() { }
    public TruckEvent(Guid id, Guid companyId, Guid truckId, Guid? actorUserId,
        string eventCode, string? metadata, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        TruckId = truckId;
        ActorUserId = actorUserId;
        EventCode = eventCode;
        Metadata = metadata;
    }
    public Guid CompanyId { get; private set; }
    public Guid TruckId { get; private set; }
    public Guid? ActorUserId { get; private set; }
    public string EventCode { get; private set; } = string.Empty;
    public string? Metadata { get; private set; }
}
