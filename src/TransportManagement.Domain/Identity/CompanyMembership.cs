using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public sealed class CompanyMembership : Entity, ITenantOwned
{
    private CompanyMembership() { }

    public CompanyMembership(Guid id, Guid companyId, Guid accountId,
        MembershipStatus status, Guid? invitedByAccountId, DateTimeOffset now)
        : base(id, now)
    {
        if (companyId == Guid.Empty || accountId == Guid.Empty)
            throw new DomainRuleException("Membership identity is required.",
                "MEMBERSHIP_IDENTITY_REQUIRED");
        CompanyId = companyId;
        AccountId = accountId;
        Status = status;
        InvitedByAccountId = invitedByAccountId;
        if (status == MembershipStatus.Active) JoinedAt = now;
        Version = 1;
    }

    public Guid CompanyId { get; private set; }
    public Guid AccountId { get; private set; }
    public MembershipStatus Status { get; private set; }
    public Guid? InvitedByAccountId { get; private set; }
    public DateTimeOffset? JoinedAt { get; private set; }
    public DateTimeOffset? SuspendedAt { get; private set; }
    public DateTimeOffset? RevokedAt { get; private set; }
    public DateTimeOffset? LeftAt { get; private set; }
    public long Version { get; private set; }
    public bool IsActive => Status == MembershipStatus.Active;

    public void Activate(DateTimeOffset now)
    {
        if (Status is MembershipStatus.Revoked or MembershipStatus.Left)
            throw new DomainRuleException("This membership cannot be reactivated.",
                "MEMBERSHIP_NOT_ACTIVE");
        Status = MembershipStatus.Active;
        JoinedAt ??= now;
        SuspendedAt = null;
        Version++;
        Touch(now);
    }

    public void Suspend(DateTimeOffset now)
    {
        EnsureActive();
        Status = MembershipStatus.Suspended;
        SuspendedAt = now;
        Version++;
        Touch(now);
    }

    public void Revoke(DateTimeOffset now)
    {
        if (Status == MembershipStatus.Revoked) return;
        Status = MembershipStatus.Revoked;
        RevokedAt = now;
        Version++;
        Touch(now);
    }

    public void Leave(DateTimeOffset now)
    {
        EnsureActive();
        Status = MembershipStatus.Left;
        LeftAt = now;
        Version++;
        Touch(now);
    }

    private void EnsureActive()
    {
        if (!IsActive)
            throw new DomainRuleException("The membership is not active.",
                "MEMBERSHIP_NOT_ACTIVE");
    }
}
