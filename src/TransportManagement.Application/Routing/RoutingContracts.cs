namespace TransportManagement.Application.Routing;

public enum RouteProfile
{
    Driving
}

public sealed record GeoCoordinate(decimal Latitude, decimal Longitude);

public sealed record RouteStopRequest(
    int Sequence,
    string Type,
    string Name,
    string? Address,
    decimal Latitude,
    decimal Longitude,
    DateTimeOffset? PlannedArrivalAt = null,
    int? PlannedServiceDurationMinutes = null);

public sealed record RoutePreviewRequest(
    IReadOnlyList<RouteStopRequest> Stops,
    RouteProfile Profile = RouteProfile.Driving);

public sealed record RouteResultResponse(
    IReadOnlyList<GeoCoordinate> Coordinates,
    string Geometry,
    string GeometryFormat,
    int GeometryVersion,
    decimal DistanceMeters,
    int EstimatedDurationSeconds,
    string ProviderName,
    string? ProviderRouteId,
    DateTimeOffset CalculatedAt,
    RouteProfile RouteProfile,
    IReadOnlyList<string> Warnings,
    string StopsFingerprint);

public sealed record LocationSearchResponse(
    string? ProviderPlaceId,
    string DisplayName,
    string? Address,
    decimal Latitude,
    decimal Longitude,
    IReadOnlyList<decimal>? BoundingBox,
    string ProviderName);

public sealed record RouteProgressResponse(
    Guid TripId,
    Guid? TruckId,
    decimal PlannedDistanceMeters,
    decimal? TravelledDistanceMeters,
    decimal? RemainingDistanceMeters,
    decimal? ProgressPercent,
    DateTimeOffset? EstimatedArrivalAt,
    decimal? DistanceFromPlannedRouteMeters,
    bool? IsOffRoute,
    int? CurrentSegmentIndex,
    string OperationalPhase,
    DateTimeOffset? LastPositionAt);
