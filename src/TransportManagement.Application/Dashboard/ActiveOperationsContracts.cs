namespace TransportManagement.Application.Dashboard;

public sealed record ActiveOperationsQuery(
    int Limit = 100,
    string? Search = null,
    Guid? ClientId = null,
    Guid? TruckId = null,
    Guid? DriverId = null,
    string? Phase = null,
    bool AttentionOnly = false);

public sealed record ActiveTripOperationalResponse(
    Guid TripId,
    string TripNumber,
    Guid ClientId,
    string ClientName,
    Guid? TruckId,
    string? TruckPlateNumber,
    string? TruckFleetCode,
    string? TruckPhotoVersion,
    string? TruckPhotoThumbnailUrl,
    Guid? DriverId,
    string? DriverName,
    string Status,
    string OperationalPhase,
    string NextMilestone,
    string? NextStopName,
    decimal? ProgressPercent,
    decimal? RemainingDistanceMeters,
    DateTimeOffset? EstimatedArrivalAt,
    DateTimeOffset? LastPositionAt,
    string TrackingHealth,
    bool? IsOnline,
    bool? IsOffRoute,
    string AttentionCode,
    int AttentionPriority,
    DateTimeOffset? WaitingSince);

public sealed record ActiveOperationsResponse(
    IReadOnlyList<ActiveTripOperationalResponse> Items,
    int TotalCount,
    DateTimeOffset GeneratedAt);
