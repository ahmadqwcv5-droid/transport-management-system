using TransportManagement.Domain.Tracking;

namespace TransportManagement.Application.Tracking;

public sealed record TruckPositionResponse(
    Guid TruckId, string PlateNumber, string TruckStatus,
    decimal Latitude, decimal Longitude, decimal Speed, decimal Heading,
    DateTimeOffset RecordedAt, bool IsOnline, string TrackingState,
    Guid? CurrentTripId, string? DriverName, MovementPhase? MovementPhase,
    Guid? RepositioningPlanId, string? PhotoVersion = null,
    string? PhotoThumbnailUrl = null);

public sealed record SimulatorControlRequest(
    string Action, Guid? TruckId = null, double? SpeedMultiplier = null,
    decimal? Latitude = null, decimal? Longitude = null);

public sealed record SimulatorStateResponse(
    bool Enabled, bool Running, double SpeedMultiplier, int Step);

public sealed record SimulatorTruckResponse(
    Guid TruckId, string PlateNumber, string TruckStatus, string LocationState,
    decimal? Latitude, decimal? Longitude, decimal? Heading,
    DateTimeOffset? RecordedAt, int? PositionAgeSeconds,
    int MaximumPositionAgeSeconds, bool? IsOnline,
    Guid? CurrentTripId, MovementPhase? MovementPhase);

public sealed record TripTrailPointResponse(
    Guid PositionId, decimal Latitude, decimal Longitude, decimal Speed,
    decimal Heading, bool IsOnline, DateTimeOffset RecordedAt, string Source);

public sealed record TripTrailSegmentResponse(
    string Id, Guid TrackingRunId, Guid? RoutePlanId,
    Guid? RepositioningPlanId, MovementPhase? MovementPhase,
    IReadOnlyList<TripTrailPointResponse> Points);

public sealed record TripTrackingHistoryResponse(
    Guid TripId, Guid TruckId, int PointCount,
    IReadOnlyList<TripTrailSegmentResponse> Segments);

public sealed record TrackingPolicy(
    TimeSpan OfflineThreshold,
    TimeSpan HistoryHeartbeat,
    TimeSpan TrailGapThreshold,
    decimal TrailJumpThresholdMeters,
    int MaxTripHistoryPoints,
    decimal SimulatorRestoreProjectionToleranceMeters = 500,
    TimeSpan? SimulatorHeartbeat = null,
    decimal CoordinateTolerance = 0.00001m,
    decimal SpeedTolerance = 0.5m,
    decimal HeadingTolerance = 1m);
