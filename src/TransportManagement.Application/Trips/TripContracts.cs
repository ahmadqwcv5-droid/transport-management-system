using System.ComponentModel.DataAnnotations;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed record TripRequest(
    Guid ClientId,
    [param: Required, MaxLength(1000)] string CargoDescription,
    DateTimeOffset? PlannedStartAt,
    [param: Range(typeof(decimal), "0", "999999999999.99")] decimal? Price,
    [param: MaxLength(2000)] string? Notes,
    IReadOnlyList<RouteStopRequest>? Stops = null,
    RouteProfile RouteProfile = RouteProfile.Driving,
    long? ExpectedVersion = null);
public sealed record UpdateTripStopsRequest(
    [param: Required] IReadOnlyList<RouteStopRequest> Stops, long ExpectedVersion);
public sealed record CalculateTripRouteRequest(RouteProfile RouteProfile = RouteProfile.Driving);
public sealed record AssignTripRequest(Guid TruckId, Guid DriverId);
public sealed record ResourceReservation(
    Guid ResourceId, Guid TripId, string TripNumber);
public sealed record AssignmentResourceOptionResponse(
    Guid Id, string DisplayName, string Status, bool IsEligible,
    string ReasonCode, Guid? ConflictingTripId = null,
    string? ConflictingTripNumber = null, string? FleetCode = null,
    string? ResourceType = null, decimal? PayloadCapacity = null,
    string? PayloadUnit = null, Guid? DefaultDriverId = null,
    string? PhotoVersion = null, string? PhotoThumbnailUrl = null);
public sealed record AssignmentOptionsResponse(
    Guid TripId, Guid? CurrentTruckId, Guid? CurrentDriverId,
    bool CanAssign, IReadOnlyList<AssignmentResourceOptionResponse> Trucks,
    IReadOnlyList<AssignmentResourceOptionResponse> Drivers,
    Guid? SuggestedDefaultDriverId = null,
    string? DefaultDriverSuggestionReasonCode = null);
public sealed record CancelTripRequest([param: MaxLength(500)] string Reason);
public sealed record ManagerOverrideRequest(
    [param: Required, MinLength(5), MaxLength(500)] string Reason);
public sealed record DispatchToPickupRequest(Guid? RepositioningPlanId);
public sealed record TripListQuery(
    int Page = 1, int PageSize = 20, string? Search = null,
    string? OperationalGroup = null, TripStatus? Status = null,
    bool? Archived = null, Guid? ClientId = null, Guid? TruckId = null,
    Guid? DriverId = null, DateTimeOffset? PlannedFrom = null,
    DateTimeOffset? PlannedTo = null, string Sort = "plannedStart",
    string Direction = "desc");
public sealed record TripPageResponse(
    IReadOnlyList<TripResponse> Items, int TotalCount, int Page,
    int PageSize, int TotalPages);
public sealed record TripReadinessResponse(
    bool CanCalculateRoute, bool CanAssign, bool CanDispatch,
    IReadOnlyList<string> MissingRequirements);
public sealed record TripEventResponse(
    Guid Id, string EventType, DateTimeOffset OccurredAt, Guid? ActorUserId,
    string ActorDisplayName, string Source, string? Metadata);
public sealed record TripTimelineResponse(
    IReadOnlyList<TripEventResponse> Items, int TotalCount, int Page,
    int PageSize, int TotalPages);
public sealed record DispatchPolicy(
    TimeSpan MaximumPositionAge, decimal PickupArrivalRadiusMeters,
    decimal ProposalOriginMovementToleranceMeters,
    decimal SimulatorRestoreProjectionToleranceMeters);

public sealed record TripResponse(
    Guid Id, string TripNumber, Guid ClientId, Guid? TruckId, Guid? DriverId,
    string? Origin, string? Destination, string CargoDescription,
    DateTimeOffset? PlannedStartAt, DateTimeOffset? ActualStartAt,
    DateTimeOffset? ArrivedPickupAt, DateTimeOffset? ArrivedDeliveryAt,
    DateTimeOffset? DeliveredAt,
    DateTimeOffset? CompletedAt, decimal? Price, string? Notes,
    TripStatus Status, bool IsArchived, DateTimeOffset? ArchivedAt,
    string? CancellationReason, DateTimeOffset? CancelledAt, long Version,
    TripReadinessResponse Readiness, IReadOnlyList<string> AllowedActions,
    IReadOnlyList<TripStopResponse> Stops, TripRoutePlanResponse? RoutePlan,
    TripRepositioningPlanResponse? RepositioningPlan,
    bool RequiresLocationSelection, DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
public sealed record TripRepositioningPlanResponse(
    Guid Id, Guid TripId, Guid TruckId, decimal OriginLatitude,
    decimal OriginLongitude, decimal DestinationLatitude,
    decimal DestinationLongitude, Guid? SourceTruckPositionId,
    DateTimeOffset SourcePositionAt, string Geometry, string GeometryFormat,
    int GeometryVersion, decimal DistanceMeters, int EstimatedDurationSeconds,
    string ProviderName, string RouteProfile, DateTimeOffset CalculatedAt,
    string? ProviderRouteId, RepositioningPlanStatus Status,
    DateTimeOffset? DispatchedAt, DateTimeOffset? ArrivedPickupAt);
public sealed record RepositioningPreviewResponse(
    Guid TripId, bool AlreadyAtPickup, decimal DirectDistanceToPickupMeters,
    int SourcePositionAgeSeconds, TripRepositioningPlanResponse? Plan);
public sealed record RepositioningProgressResponse(
    Guid TripId, Guid TruckId, string OperationalPhase,
    decimal PlannedDistanceMeters, decimal? TravelledDistanceMeters,
    decimal? RemainingDistanceMeters, decimal? ProgressPercent,
    DateTimeOffset? EstimatedArrivalAt, DateTimeOffset? LastPositionAt,
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
