using System.ComponentModel.DataAnnotations;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Routing;

namespace TransportManagement.Application.Trips;

public sealed record TripRequest(
    Guid ClientId,
    [param: Required, MaxLength(1000)] string CargoDescription,
    DateTimeOffset PlannedStartAt,
    [param: Range(typeof(decimal), "0", "999999999999.99")] decimal Price,
    [param: MaxLength(2000)] string? Notes,
    IReadOnlyList<RouteStopRequest> Stops,
    RouteProfile RouteProfile = RouteProfile.Driving);

public sealed record AssignTripRequest(Guid TruckId, Guid DriverId);

public sealed record TripResponse(
    Guid Id,
    Guid ClientId,
    Guid? TruckId,
    Guid? DriverId,
    string Origin,
    string Destination,
    string CargoDescription,
    DateTimeOffset PlannedStartAt,
    DateTimeOffset? ActualStartAt,
    DateTimeOffset? DeliveredAt,
    DateTimeOffset? CompletedAt,
    decimal Price,
    string? Notes,
    TripStatus Status,
    IReadOnlyList<string> AllowedActions,
    IReadOnlyList<TripStopResponse> Stops,
    TripRoutePlanResponse? RoutePlan,
    bool RequiresLocationSelection,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record TripStopResponse(
    Guid Id, int Sequence, TripStopType Type, string Name, string? Address,
    decimal? Latitude, decimal? Longitude, DateTimeOffset? PlannedArrivalAt,
    int? PlannedServiceDurationMinutes);

public sealed record TripRoutePlanResponse(
    Guid Id, string Geometry, string GeometryFormat, int GeometryVersion,
    decimal DistanceMeters, int EstimatedDurationSeconds, string ProviderName,
    string RouteProfile, DateTimeOffset CalculatedAt, string StopsFingerprint,
    string? ProviderRouteId, string? Warnings);
