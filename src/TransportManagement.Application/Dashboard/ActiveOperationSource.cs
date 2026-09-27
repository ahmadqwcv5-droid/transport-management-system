using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Dashboard;

public sealed record ActiveOperationSource(
    Guid TripId, string TripNumber, Guid ClientId, string ClientName,
    Guid? TruckId, string? TruckPlateNumber, string? TruckFleetCode,
    string? TruckPhotoVersion, Guid? DriverId, string? DriverName,
    TripStatus Status, DateTimeOffset UpdatedAt,
    string? PickupName, string? DeliveryName,
    string? CargoRouteGeometry, decimal? CargoRouteDistanceMeters,
    string? ApproachRouteGeometry, decimal? ApproachRouteDistanceMeters,
    Guid? PositionTripId, decimal? Latitude, decimal? Longitude,
    decimal? Speed, bool? IsOnline, DateTimeOffset? PositionRecordedAt);
