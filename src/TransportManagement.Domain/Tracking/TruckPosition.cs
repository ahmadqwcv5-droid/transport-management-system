using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Tracking;

public sealed class TruckPosition : Entity, ITenantOwned
{
    private TruckPosition() { }

    public TruckPosition(Guid id, Guid companyId, Guid truckId, decimal latitude,
        decimal longitude, decimal speed, decimal heading, bool isOnline,
        DateTimeOffset recordedAt, string source) : base(id, recordedAt)
    {
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new DomainRuleException("Position coordinates are invalid.", "INVALID_POSITION");
        CompanyId = companyId;
        TruckId = truckId;
        Latitude = latitude;
        Longitude = longitude;
        Speed = Math.Max(0, speed);
        Heading = ((heading % 360) + 360) % 360;
        IsOnline = isOnline;
        RecordedAt = recordedAt;
        Source = source;
    }

    public Guid CompanyId { get; private set; }
    public Guid TruckId { get; private set; }
    public decimal Latitude { get; private set; }
    public decimal Longitude { get; private set; }
    public decimal Speed { get; private set; }
    public decimal Heading { get; private set; }
    public bool IsOnline { get; private set; }
    public DateTimeOffset RecordedAt { get; private set; }
    public string Source { get; private set; } = string.Empty;
}
