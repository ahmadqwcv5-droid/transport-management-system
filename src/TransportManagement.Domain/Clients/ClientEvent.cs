using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Clients;

public sealed class ClientEvent : Entity, ITenantOwned
{
    private ClientEvent() { }
    public ClientEvent(Guid id, Guid companyId, Guid clientId, Guid? actorUserId,
        string eventCode, string? metadata, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        ClientId = clientId;
        ActorUserId = actorUserId;
        EventCode = eventCode;
        Metadata = metadata;
    }
    public Guid CompanyId { get; private set; }
    public Guid ClientId { get; private set; }
    public Guid? ActorUserId { get; private set; }
    public string EventCode { get; private set; } = string.Empty;
    public string? Metadata { get; private set; }
}
