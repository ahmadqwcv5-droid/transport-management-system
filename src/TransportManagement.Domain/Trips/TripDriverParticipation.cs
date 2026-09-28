using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripDriverParticipation : Entity, ITenantOwned
{
    private TripDriverParticipation() { }

    public TripDriverParticipation(Guid id, Guid companyId, Guid tripId,
        Guid driverId, DateTimeOffset startedAt, string source,
        TripStatus startedPhase, Guid? assignedByAccountId,
        Guid? handoverRequestId, Guid? startedPositionId, DateTimeOffset now)
        : base(id, now)
    {
        CompanyId = companyId;
        TripId = tripId;
        DriverId = driverId;
        StartedAt = startedAt;
        Source = source;
        StartedPhase = startedPhase;
        AssignedByAccountId = assignedByAccountId;
        HandoverRequestId = handoverRequestId;
        StartedPositionId = startedPositionId;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public Guid DriverId { get; private set; }
    public DateTimeOffset StartedAt { get; private set; }
    public DateTimeOffset? EndedAt { get; private set; }
    public string Source { get; private set; } = string.Empty;
    public TripStatus StartedPhase { get; private set; }
    public TripStatus? EndedPhase { get; private set; }
    public Guid? StartedPositionId { get; private set; }
    public Guid? EndedPositionId { get; private set; }
    public Guid? AssignedByAccountId { get; private set; }
    public Guid? ApprovedByAccountId { get; private set; }
    public Guid? HandoverRequestId { get; private set; }
    public bool IsActive => EndedAt is null;

    public void End(DateTimeOffset endedAt, TripStatus phase,
        Guid? positionId, Guid? approvedByAccountId)
    {
        if (!IsActive) return;
        if (endedAt < StartedAt)
            throw new DomainRuleException("Participation end precedes its start.",
                "PARTICIPATION_TIME_INVALID");
        EndedAt = endedAt;
        EndedPhase = phase;
        EndedPositionId = positionId;
        ApprovedByAccountId = approvedByAccountId;
        Touch(endedAt);
    }
}
