using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class OperationNotification : Entity, ITenantOwned
{
    private OperationNotification() { }

    public OperationNotification(Guid id, Guid companyId, string type, string severity,
        Guid? tripId, Guid? truckId, Guid? driverId, string eventKey,
        string? dataJson, DateTimeOffset now) : base(id, now)
    {
        if (string.IsNullOrWhiteSpace(type) || type.Length > 80
            || string.IsNullOrWhiteSpace(eventKey) || eventKey.Length > 200)
            throw new DomainRuleException("Notification identity is invalid.");
        if (dataJson?.Length > 4000)
            throw new DomainRuleException("Notification data is too large.");
        CompanyId = companyId;
        Type = type;
        Severity = severity;
        TripId = tripId;
        TruckId = truckId;
        DriverId = driverId;
        EventKey = eventKey;
        DataJson = dataJson;
    }

    public Guid CompanyId { get; private set; }
    public string Type { get; private set; } = string.Empty;
    public string Severity { get; private set; } = "Info";
    public Guid? TripId { get; private set; }
    public Guid? TruckId { get; private set; }
    public Guid? DriverId { get; private set; }
    public string EventKey { get; private set; } = string.Empty;
    public string? DataJson { get; private set; }
    public DateTimeOffset? ReadAt { get; private set; }
    public Guid? ReadByUserId { get; private set; }

    public void MarkRead(Guid userId, DateTimeOffset now)
    {
        if (ReadAt.HasValue) return;
        ReadAt = now;
        ReadByUserId = userId;
        Touch(now);
    }
}
