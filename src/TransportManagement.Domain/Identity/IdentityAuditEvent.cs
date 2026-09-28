using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class IdentityAuditEvent : Entity, ITenantOwned
{
    private IdentityAuditEvent() { }

    public IdentityAuditEvent(Guid id, Guid companyId, Guid? accountId,
        Guid? actorAccountId, string eventCode, string? dataJson,
        DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        AccountId = accountId;
        ActorAccountId = actorAccountId;
        EventCode = eventCode;
        DataJson = dataJson;
    }

    public Guid CompanyId { get; private set; }
    public Guid? AccountId { get; private set; }
    public Guid? ActorAccountId { get; private set; }
    public string EventCode { get; private set; } = string.Empty;
    public string? DataJson { get; private set; }
}
