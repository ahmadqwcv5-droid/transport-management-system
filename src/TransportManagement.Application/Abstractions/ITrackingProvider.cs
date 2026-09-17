namespace TransportManagement.Application.Abstractions;

public sealed record TrackingSample(
    Guid TruckId, decimal Latitude, decimal Longitude, decimal Speed,
    decimal Heading, bool IsOnline, DateTimeOffset RecordedAt, string Source);

public sealed record SimulatorCommand(string Action, Guid? TruckId = null, double? SpeedMultiplier = null);
public sealed record SimulatorState(bool Enabled, bool Running, double SpeedMultiplier, int Step);

public interface ITrackingProvider
{
    bool IsSimulator { get; }
    IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<Guid> truckIds, DateTimeOffset now);
    SimulatorState Control(
        Guid companyId, IReadOnlyCollection<Guid> truckIds, SimulatorCommand command, DateTimeOffset now);
}
