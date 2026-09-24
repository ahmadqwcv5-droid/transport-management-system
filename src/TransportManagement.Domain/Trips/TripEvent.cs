using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripEvent : Entity, ITenantOwned
{
    private TripEvent() { }

    public TripEvent(Guid id, Guid companyId, Guid tripId, string eventType,
        DateTimeOffset occurredAt, Guid? actorUserId, string source,
        string? metadata, DateTimeOffset now) : base(id, now)
    {
        if (string.IsNullOrWhiteSpace(eventType) || eventType.Length > 80)
            throw new DomainRuleException("Trip event type is invalid.");
        if (source is not ("User" or "System" or "Migration" or "ManagerOverride"))
            throw new DomainRuleException("Trip event source is invalid.");
        if (metadata?.Length > 4000)
            throw new DomainRuleException("Trip event metadata is too large.");
        CompanyId = companyId;
        TripId = tripId;
        EventType = eventType;
        OccurredAt = occurredAt;
        ActorUserId = actorUserId;
        Source = source;
        Metadata = metadata;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public string EventType { get; private set; } = string.Empty;
    public DateTimeOffset OccurredAt { get; private set; }
    public Guid? ActorUserId { get; private set; }
    public string Source { get; private set; } = string.Empty;
    public string? Metadata { get; private set; }
}
