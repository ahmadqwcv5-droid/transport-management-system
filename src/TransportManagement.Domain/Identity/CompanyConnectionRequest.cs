using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Identity;

public enum CompanyConnectionRequestStatus
{
    Pending,
    Approved,
    Rejected,
    Cancelled
}

public sealed class CompanyConnectionRequest : Entity, ITenantOwned
{
    private CompanyConnectionRequest() { }

    public CompanyConnectionRequest(Guid id, Guid companyId, Guid accountId,
        string requestedRolesJson, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        AccountId = accountId;
        RequestedRolesJson = requestedRolesJson;
        Status = CompanyConnectionRequestStatus.Pending;
    }

    public Guid CompanyId { get; private set; }
    public Guid AccountId { get; private set; }
    public string RequestedRolesJson { get; private set; } = "[]";
    public CompanyConnectionRequestStatus Status { get; private set; }
    public Guid? DriverId { get; private set; }
    public Guid? ResolvedByAccountId { get; private set; }
    public DateTimeOffset? ResolvedAt { get; private set; }
    public string? ResolutionReason { get; private set; }

    public void Approve(Guid resolver, Guid? driverId, DateTimeOffset now)
    {
        EnsurePending();
        Status = CompanyConnectionRequestStatus.Approved;
        DriverId = driverId;
        ResolvedByAccountId = resolver;
        ResolvedAt = now;
        Touch(now);
    }

    public void Reject(Guid resolver, string? reason, DateTimeOffset now)
    {
        EnsurePending();
        Status = CompanyConnectionRequestStatus.Rejected;
        ResolvedByAccountId = resolver;
        ResolutionReason = Normalize(reason);
        ResolvedAt = now;
        Touch(now);
    }

    public void Cancel(DateTimeOffset now)
    {
        EnsurePending();
        Status = CompanyConnectionRequestStatus.Cancelled;
        ResolvedAt = now;
        Touch(now);
    }

    private void EnsurePending()
    {
        if (Status != CompanyConnectionRequestStatus.Pending)
            throw new DomainRuleException("The request was already resolved.",
                "CONNECTION_REQUEST_ALREADY_RESOLVED");
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
