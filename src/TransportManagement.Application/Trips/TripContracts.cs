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

public sealed record DispatchToPickupRequest(Guid? RepositioningPlanId);

public sealed record DispatchPolicy(
    TimeSpan MaximumPositionAge,
    decimal PickupArrivalRadiusMeters,
    decimal ProposalOriginMovementToleranceMeters,
    decimal SimulatorRestoreProjectionToleranceMeters);

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
    DateTimeOffset? ArrivedPickupAt,
    DateTimeOffset? DeliveredAt,
    DateTimeOffset? CompletedAt,
    decimal Price,
    string? Notes,
    TripStatus Status,
    IReadOnlyList<string> AllowedActions,
    IReadOnlyList<TripStopResponse> Stops,
    TripRoutePlanResponse? RoutePlan,
    TripRepositioningPlanResponse? RepositioningPlan,
    bool RequiresLocationSelection,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

public sealed record TripRepositioningPlanResponse(
    Guid Id,
    Guid TripId,
    Guid TruckId,
    decimal OriginLatitude,
    decimal OriginLongitude,
    decimal DestinationLatitude,
    decimal DestinationLongitude,
    Guid? SourceTruckPositionId,
    DateTimeOffset SourcePositionAt,
    string Geometry,
    string GeometryFormat,
    int GeometryVersion,
    decimal DistanceMeters,
    int EstimatedDurationSeconds,
    string ProviderName,
    string RouteProfile,
    DateTimeOffset CalculatedAt,
    string? ProviderRouteId,
    RepositioningPlanStatus Status,
    DateTimeOffset? DispatchedAt,
    DateTimeOffset? ArrivedPickupAt);

public sealed record RepositioningPreviewResponse(
    Guid TripId,
    bool AlreadyAtPickup,
    decimal DirectDistanceToPickupMeters,
    int SourcePositionAgeSeconds,
    TripRepositioningPlanResponse? Plan);

public sealed record RepositioningProgressResponse(
    Guid TripId,
    Guid TruckId,
    string OperationalPhase,
    decimal PlannedDistanceMeters,
    decimal? TravelledDistanceMeters,
    decimal? RemainingDistanceMeters,
    decimal? ProgressPercent,
    DateTimeOffset? EstimatedArrivalAt,
    DateTimeOffset? LastPositionAt,
    bool CargoProgressStarted);

public sealed record TripStopResponse(
    Guid Id, int Sequence, TripStopType Type, string Name, string? Address,
    decimal? Latitude, decimal? Longitude, DateTimeOffset? PlannedArrivalAt,
    int? PlannedServiceDurationMinutes);

public sealed record TripRoutePlanResponse(
    Guid Id, string Geometry, string GeometryFormat, int GeometryVersion,
    decimal DistanceMeters, int EstimatedDurationSeconds, string ProviderName,
    string RouteProfile, DateTimeOffset CalculatedAt, string StopsFingerprint,
    string? ProviderRouteId, string? Warnings);
