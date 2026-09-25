using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class CompanyUserEvent : Entity, ITenantOwned
{
    private CompanyUserEvent() { }

    public CompanyUserEvent(Guid id, Guid companyId, Guid subjectUserId,
        Guid actorUserId, string eventCode, string? metadata, DateTimeOffset now) : base(id, now)
    {
        if (string.IsNullOrWhiteSpace(eventCode) || eventCode.Length > 80)
            throw new DomainRuleException("A valid user event code is required.");
        if (metadata?.Length > 2000)
            throw new DomainRuleException("User event metadata is too large.");
        CompanyId = companyId;
        SubjectUserId = subjectUserId;
        ActorUserId = actorUserId;
        EventCode = eventCode;
        Metadata = metadata;
    }

    public Guid CompanyId { get; private set; }
    public Guid SubjectUserId { get; private set; }
    public Guid ActorUserId { get; private set; }
    public string EventCode { get; private set; } = string.Empty;
    public string? Metadata { get; private set; }
}
