using TransportManagement.Application.Trips;

namespace TransportManagement.Application.Drivers;

public sealed record DriverMyTripResponse(Guid DriverId, string DriverName,
    TripResponse? Trip);

public sealed record DriverWorkspaceDriver(Guid Id, string FullName);
public sealed record DriverWorkspaceTruck(Guid Id, string PlateNumber, string? FleetCode,
    string? PhotoVersion, string? PhotoThumbnailUrl);
public sealed record DriverWorkspacePosition(decimal Latitude, decimal Longitude,
    decimal Speed, decimal Heading, DateTimeOffset RecordedAt, bool IsOnline);
public sealed record DriverTruckSessionResponse(Guid Id, Guid TruckId, Guid LastTripId,
    DateTimeOffset StartedAt);
public sealed record DriverWorkspaceResponse(
    string State,
    DriverWorkspaceDriver? Driver,
    TripResponse? CurrentTrip,
    DriverWorkspaceTruck? Truck,
    DriverWorkspacePosition? CurrentPosition,
    string TrackingState,
    TripRoutePlanResponse? ActiveRoute,
    TripRepositioningPlanResponse? ApproachRoute,
    TripStopResponse? NextStop,
    decimal? RemainingDistanceMeters,
    DateTimeOffset? EstimatedArrivalAt,
    IReadOnlyList<string> AllowedActions,
    DriverTruckSessionResponse? VehicleSession = null);
