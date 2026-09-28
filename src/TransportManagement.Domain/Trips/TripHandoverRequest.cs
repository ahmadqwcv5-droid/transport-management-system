using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public enum TripHandoverStatus
{
    Pending,
    Approved,
    Rejected,
    Cancelled,
    Expired
}

public sealed class TripHandoverRequest : Entity, ITenantOwned
{
    private TripHandoverRequest() { }

    public TripHandoverRequest(Guid id, Guid companyId, Guid tripId,
        Guid truckId, Guid currentDriverId, Guid requestingDriverId,
        long expectedTripVersion, DateTimeOffset expiresAt,
        Guid requestedByAccountId, string? reason, DateTimeOffset now)
        : base(id, now)
    {
        if (currentDriverId == requestingDriverId)
            throw new DomainRuleException("The current Driver cannot request their own handover.",
                "HANDOVER_SELF_REQUEST");
        CompanyId = companyId;
        TripId = tripId;
        TruckId = truckId;
        CurrentDriverId = currentDriverId;
        RequestingDriverId = requestingDriverId;
        ExpectedTripVersion = expectedTripVersion;
        ExpiresAt = expiresAt;
        RequestedByAccountId = requestedByAccountId;
        Reason = Normalize(reason);
        Status = TripHandoverStatus.Pending;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public Guid TruckId { get; private set; }
    public Guid CurrentDriverId { get; private set; }
    public Guid RequestingDriverId { get; private set; }
    public long ExpectedTripVersion { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }
    public Guid RequestedByAccountId { get; private set; }
    public string? Reason { get; private set; }
    public TripHandoverStatus Status { get; private set; }
    public Guid? ResolvedByAccountId { get; private set; }
    public string? ResolutionReason { get; private set; }
    public DateTimeOffset? ResolvedAt { get; private set; }

    public bool IsExpired(DateTimeOffset now) =>
        Status == TripHandoverStatus.Pending && ExpiresAt <= now;

    public void Approve(Guid approver, string? reason, DateTimeOffset now)
    {
        EnsurePending(now);
        Status = TripHandoverStatus.Approved;
        ResolvedByAccountId = approver;
        ResolutionReason = Normalize(reason);
        ResolvedAt = now;
        Touch(now);
    }

    public void Reject(Guid approver, string? reason, DateTimeOffset now)
    {
        EnsurePending(now);
        Status = TripHandoverStatus.Rejected;
        ResolvedByAccountId = approver;
        ResolutionReason = Normalize(reason);
        ResolvedAt = now;
        Touch(now);
    }

    public void Cancel(DateTimeOffset now)
    {
        EnsurePending(now);
        Status = TripHandoverStatus.Cancelled;
        ResolvedAt = now;
        Touch(now);
    }

    public void Expire(DateTimeOffset now)
    {
        if (!IsExpired(now)) return;
        Status = TripHandoverStatus.Expired;
        ResolvedAt = now;
        Touch(now);
    }

    private void EnsurePending(DateTimeOffset now)
    {
        if (IsExpired(now))
        {
            Expire(now);
            throw new DomainRuleException("The handover request is stale.",
                "HANDOVER_REQUEST_STALE");
        }
        if (Status != TripHandoverStatus.Pending)
            throw new DomainRuleException("The handover was already resolved.",
                "HANDOVER_ALREADY_RESOLVED");
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
