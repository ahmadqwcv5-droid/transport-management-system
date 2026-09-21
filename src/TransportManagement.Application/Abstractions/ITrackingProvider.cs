using TransportManagement.Application.Routing;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Application.Abstractions;

public sealed record TrackingSample(
    Guid TruckId, decimal Latitude, decimal Longitude, decimal Speed,
    decimal Heading, bool IsOnline, DateTimeOffset RecordedAt, string Source,
    Guid TrackingRunId);

public sealed record SimulatorCommand(string Action, Guid? TruckId = null, double? SpeedMultiplier = null);
public sealed record SimulatorState(bool Enabled, bool Running, double SpeedMultiplier, int Step);
public sealed record TrackingTarget(
    Guid TruckId,
    Guid? TripId,
    Guid? RoutePlanId,
    string? RouteRevision,
    IReadOnlyList<GeoCoordinate> Route,
    bool CanMove,
    MovementPhase? MovementPhase = null,
    Guid? RepositioningPlanId = null,
    GeoCoordinate? RestorePosition = null,
    decimal RestoreProjectionToleranceMeters = 500);

public interface ITrackingProvider
{
    bool IsSimulator { get; }
    IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, DateTimeOffset now);
    SimulatorState Control(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, SimulatorCommand command, DateTimeOffset now);
}
