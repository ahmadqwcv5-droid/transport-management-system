using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public enum CompanyInvitationStatus
{
    Pending,
    Accepted,
    Expired,
    Revoked,
    Declined
}

public sealed class CompanyInvitation : Entity, ITenantOwned
{
    private CompanyInvitation() { }

    public CompanyInvitation(Guid id, Guid companyId, string email,
        string rolesJson, Guid? driverId, string tokenHash,
        DateTimeOffset expiresAt, Guid inviterAccountId, DateTimeOffset now)
        : base(id, now)
    {
        CompanyId = companyId;
        Email = email.Trim().ToLowerInvariant();
        RolesJson = rolesJson;
        DriverId = driverId;
        TokenHash = tokenHash;
        ExpiresAt = expiresAt;
        InviterAccountId = inviterAccountId;
        Status = CompanyInvitationStatus.Pending;
    }

    public Guid CompanyId { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string RolesJson { get; private set; } = "[]";
    public Guid? DriverId { get; private set; }
    public string TokenHash { get; private set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; private set; }
    public Guid InviterAccountId { get; private set; }
    public CompanyInvitationStatus Status { get; private set; }
    public Guid? AcceptedByAccountId { get; private set; }
    public DateTimeOffset? ResolvedAt { get; private set; }

    public bool IsExpired(DateTimeOffset now) =>
        Status == CompanyInvitationStatus.Pending && ExpiresAt <= now;

    public void Accept(Guid accountId, DateTimeOffset now)
    {
        EnsurePending(now);
        Status = CompanyInvitationStatus.Accepted;
        AcceptedByAccountId = accountId;
        ResolvedAt = now;
        Touch(now);
    }

    public void Decline(DateTimeOffset now)
    {
        EnsurePending(now);
        Status = CompanyInvitationStatus.Declined;
        ResolvedAt = now;
        Touch(now);
    }

    public void Revoke(DateTimeOffset now)
    {
        EnsurePending(now);
        Status = CompanyInvitationStatus.Revoked;
        ResolvedAt = now;
        Touch(now);
    }

    public void Expire(DateTimeOffset now)
    {
        if (!IsExpired(now)) return;
        Status = CompanyInvitationStatus.Expired;
        ResolvedAt = now;
        Touch(now);
    }

    private void EnsurePending(DateTimeOffset now)
    {
        if (IsExpired(now))
        {
            Expire(now);
            throw new DomainRuleException("The invitation has expired.",
                "INVITATION_EXPIRED");
        }
        if (Status != CompanyInvitationStatus.Pending)
            throw new DomainRuleException("The invitation was already resolved.",
                "INVITATION_ALREADY_USED");
    }
}
