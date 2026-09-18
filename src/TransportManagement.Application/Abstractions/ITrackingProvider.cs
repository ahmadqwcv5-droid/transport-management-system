using TransportManagement.Application.Routing;

namespace TransportManagement.Application.Abstractions;

public sealed record TrackingSample(
    Guid TruckId, decimal Latitude, decimal Longitude, decimal Speed,
    decimal Heading, bool IsOnline, DateTimeOffset RecordedAt, string Source);

public sealed record SimulatorCommand(string Action, Guid? TruckId = null, double? SpeedMultiplier = null);
public sealed record SimulatorState(bool Enabled, bool Running, double SpeedMultiplier, int Step);
public sealed record TrackingTarget(
    Guid TruckId,
    Guid? TripId,
    string? RouteRevision,
    IReadOnlyList<GeoCoordinate> Route,
    bool CanMove);

public interface ITrackingProvider
{
    bool IsSimulator { get; }
    IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, DateTimeOffset now);
    SimulatorState Control(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, SimulatorCommand command, DateTimeOffset now);
}
