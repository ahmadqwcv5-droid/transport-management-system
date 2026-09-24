using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public enum GeofenceStage { Pickup, Delivery }

public sealed class TripGeofenceObservation : Entity, ITenantOwned
{
    private TripGeofenceObservation() { }

    public TripGeofenceObservation(Guid id, Guid companyId, Guid tripId,
        GeofenceStage stage, string routeIdentity, DateTimeOffset now) : base(id, now)
    {
        CompanyId = companyId;
        TripId = tripId;
        Stage = stage;
        RouteIdentity = routeIdentity;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public GeofenceStage Stage { get; private set; }
    public string RouteIdentity { get; private set; } = string.Empty;
    public DateTimeOffset? FirstQualifyingAt { get; private set; }
    public DateTimeOffset? LastSampleAt { get; private set; }
    public int ConsecutiveSamples { get; private set; }
    public bool IsInside { get; private set; }
    public DateTimeOffset? ConfirmedAt { get; private set; }
    public long Version { get; private set; }

    public bool Observe(decimal distanceMeters, DateTimeOffset recordedAt,
        decimal arrivalRadiusMeters, decimal exitRadiusMeters,
        int minimumSamples, TimeSpan minimumDwell, DateTimeOffset now)
    {
        if (ConfirmedAt.HasValue || LastSampleAt >= recordedAt) return false;
        LastSampleAt = recordedAt;
        if (distanceMeters > exitRadiusMeters)
        {
            IsInside = false;
            FirstQualifyingAt = null;
            ConsecutiveSamples = 0;
        }
        else if (distanceMeters <= arrivalRadiusMeters)
        {
            if (!IsInside)
            {
                IsInside = true;
                FirstQualifyingAt = recordedAt;
                ConsecutiveSamples = 1;
            }
            else ConsecutiveSamples++;
        }
        Version++;
        Touch(now);
        if (ConsecutiveSamples < minimumSamples || FirstQualifyingAt is null
            || recordedAt - FirstQualifyingAt < minimumDwell) return false;
        ConfirmedAt = recordedAt;
        return true;
    }
}
