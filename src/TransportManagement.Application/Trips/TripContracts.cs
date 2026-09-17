using System.ComponentModel.DataAnnotations;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed record TripRequest(
    Guid ClientId,
    [param: Required, MaxLength(300)] string Origin,
    [param: Required, MaxLength(300)] string Destination,
    [param: Required, MaxLength(1000)] string CargoDescription,
    DateTimeOffset PlannedStartAt,
    [param: Range(typeof(decimal), "0", "999999999999.99")] decimal Price,
    [param: MaxLength(2000)] string? Notes);

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
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
