using TransportManagement.Domain.Common;

namespace TransportManagement.Domain.Trips;

public sealed class TripRoutePlan : Entity, ITenantOwned
{
    private TripRoutePlan() { }

    public TripRoutePlan(
        Guid id,
        Guid companyId,
        Guid tripId,
        string geometry,
        string geometryFormat,
        int geometryVersion,
        decimal distanceMeters,
        int estimatedDurationSeconds,
        string providerName,
        string routeProfile,
        DateTimeOffset calculatedAt,
        string stopsFingerprint,
        string? providerRouteId,
        string? warnings,
        DateTimeOffset now) : base(id, now)
    {
        if (string.IsNullOrWhiteSpace(geometry))
            throw new DomainRuleException("Route geometry is required.", "ROUTE_GEOMETRY_REQUIRED");
        if (distanceMeters <= 0 || estimatedDurationSeconds <= 0)
            throw new DomainRuleException("Route distance and duration must be positive.", "INVALID_ROUTE_RESULT");

        CompanyId = companyId;
        TripId = tripId;
        Geometry = geometry;
        GeometryFormat = geometryFormat;
        GeometryVersion = geometryVersion;
        DistanceMeters = distanceMeters;
        EstimatedDurationSeconds = estimatedDurationSeconds;
        ProviderName = providerName;
        RouteProfile = routeProfile;
        CalculatedAt = calculatedAt;
        StopsFingerprint = stopsFingerprint;
        ProviderRouteId = providerRouteId;
        Warnings = warnings;
    }

    public Guid CompanyId { get; private set; }
    public Guid TripId { get; private set; }
    public string Geometry { get; private set; } = string.Empty;
    public string GeometryFormat { get; private set; } = "geojson-linestring";
    public int GeometryVersion { get; private set; } = 1;
    public decimal DistanceMeters { get; private set; }
    public int EstimatedDurationSeconds { get; private set; }
    public string ProviderName { get; private set; } = string.Empty;
    public string RouteProfile { get; private set; } = string.Empty;
    public DateTimeOffset CalculatedAt { get; private set; }
    public string StopsFingerprint { get; private set; } = string.Empty;
    public string? ProviderRouteId { get; private set; }
    public string? Warnings { get; private set; }
}
