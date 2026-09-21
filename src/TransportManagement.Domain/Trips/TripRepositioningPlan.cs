using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripRepositioningPlan : Entity, ITenantOwned
{
    private TripRepositioningPlan() { }

    public TripRepositioningPlan(
        Guid id,
        Guid companyId,
        Guid tripId,
        Guid truckId,
        decimal originLatitude,
        decimal originLongitude,
        decimal destinationLatitude,
        decimal destinationLongitude,
        Guid? sourceTruckPositionId,
        DateTimeOffset sourcePositionAt,
        string geometry,
        string geometryFormat,
        int geometryVersion,
        decimal distanceMeters,
        int estimatedDurationSeconds,
        string providerName,
        string routeProfile,
        DateTimeOffset calculatedAt,
        string? providerRouteId,
        DateTimeOffset now) : base(id, now)
    {
        ValidateCoordinate(originLatitude, originLongitude);
        ValidateCoordinate(destinationLatitude, destinationLongitude);
        if (string.IsNullOrWhiteSpace(geometry))
            throw new DomainRuleException("Repositioning geometry is required.", "ROUTE_GEOMETRY_REQUIRED");
        if (distanceMeters <= 0 || estimatedDurationSeconds <= 0)
            throw new DomainRuleException("Repositioning distance and duration must be positive.", "INVALID_ROUTE_RESULT");

        CompanyId = companyId;
        TripId = tripId;
        TruckId = truckId;
        OriginLatitude = originLatitude;
        OriginLongitude = originLongitude;
        DestinationLatitude = destinationLatitude;
        DestinationLongitude = destinationLongitude;
        SourceTruckPositionId = sourceTruckPositionId;
        SourcePositionAt = sourcePositionAt;
        Geometry = geometry;
        GeometryFormat = geometryFormat;
        GeometryVersion = geometryVersion;
        DistanceMeters = distanceMeters;
        EstimatedDurationSeconds = estimatedDurationSeconds;
        ProviderName = providerName;
        RouteProfile = routeProfile;
        CalculatedAt = calculatedAt;
        ProviderRouteId = providerRouteId;
        Status = RepositioningPlanStatus.Proposed;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public Guid TruckId { get; private set; }
    public decimal OriginLatitude { get; private set; }
    public decimal OriginLongitude { get; private set; }
    public decimal DestinationLatitude { get; private set; }
    public decimal DestinationLongitude { get; private set; }
    public Guid? SourceTruckPositionId { get; private set; }
    public DateTimeOffset SourcePositionAt { get; private set; }
    public string Geometry { get; private set; } = string.Empty;
    public string GeometryFormat { get; private set; } = "geojson-linestring";
    public int GeometryVersion { get; private set; } = 1;
    public decimal DistanceMeters { get; private set; }
    public int EstimatedDurationSeconds { get; private set; }
    public string ProviderName { get; private set; } = string.Empty;
    public string RouteProfile { get; private set; } = string.Empty;
    public DateTimeOffset CalculatedAt { get; private set; }
    public string? ProviderRouteId { get; private set; }
    public RepositioningPlanStatus Status { get; private set; }
    public DateTimeOffset? DispatchedAt { get; private set; }
    public DateTimeOffset? ArrivedPickupAt { get; private set; }

    public void Activate(DateTimeOffset now)
    {
        if (Status != RepositioningPlanStatus.Proposed)
            throw new DomainRuleException("Only a proposed repositioning plan can be activated.", "REPOSITIONING_ROUTE_REQUIRED");
        Status = RepositioningPlanStatus.Active;
        DispatchedAt = now;
        Touch(now);
    }

    public void Complete(DateTimeOffset now)
    {
        if (Status == RepositioningPlanStatus.Completed) return;
        if (Status != RepositioningPlanStatus.Active)
            throw new DomainRuleException("Only an active repositioning plan can be completed.", "INVALID_TRIP_TRANSITION");
        Status = RepositioningPlanStatus.Completed;
        ArrivedPickupAt = now;
        Touch(now);
    }

    public void Expire(DateTimeOffset now)
    {
        if (Status == RepositioningPlanStatus.Proposed)
        {
            Status = RepositioningPlanStatus.Expired;
            Touch(now);
        }
    }

    private static void ValidateCoordinate(decimal latitude, decimal longitude)
    {
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180)
            throw new DomainRuleException("Repositioning coordinates are invalid.", "INVALID_POSITION");
    }
}
