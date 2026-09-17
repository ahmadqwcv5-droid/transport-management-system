namespace TransportManagement.Application.Tracking;

public sealed record TruckPositionResponse(
    Guid TruckId, string PlateNumber, string TruckStatus,
    decimal Latitude, decimal Longitude, decimal Speed, decimal Heading,
    DateTimeOffset RecordedAt, bool IsOnline, string TrackingState,
    Guid? CurrentTripId, string? DriverName);

public sealed record SimulatorControlRequest(
    string Action, Guid? TruckId = null, double? SpeedMultiplier = null);

public sealed record SimulatorStateResponse(
    bool Enabled, bool Running, double SpeedMultiplier, int Step);

public sealed record TrackingPolicy(
    TimeSpan OfflineThreshold,
    TimeSpan HistoryHeartbeat,
    decimal CoordinateTolerance = 0.00001m,
    decimal SpeedTolerance = 0.5m,
    decimal HeadingTolerance = 1m);
