using System.Collections.Concurrent;
using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Common;

namespace TransportManagement.Infrastructure.Tracking;

public sealed class SimulatedTrackingProvider : ITrackingProvider
{
    private sealed class CompanySimulation
    {
        public bool Running { get; set; }
        public double SpeedMultiplier { get; set; } = 1;
        public int Step { get; set; }
        public HashSet<Guid> OfflineTrucks { get; } = [];
    }

    private readonly ConcurrentDictionary<Guid, CompanySimulation> _states = new();
    public bool IsSimulator => true;

    public IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<Guid> truckIds, DateTimeOffset now)
    {
        var state = _states.GetOrAdd(companyId, _ => new());
        lock (state)
        {
            if (state.Running) state.Step++;
            return truckIds.Order().Select((truckId, index) => Sample(truckId, index, state, now)).ToArray();
        }
    }

    public SimulatorState Control(Guid companyId, IReadOnlyCollection<Guid> truckIds,
        SimulatorCommand command, DateTimeOffset now)
    {
        var state = _states.GetOrAdd(companyId, _ => new());
        lock (state)
        {
            switch (command.Action.Trim().ToLowerInvariant())
            {
                case "start": state.Running = true; state.OfflineTrucks.Clear(); break;
                case "pause": state.Running = false; break;
                case "resume": state.Running = true; break;
                case "stop": state.Running = false; state.OfflineTrucks.UnionWith(truckIds); break;
                case "reset": state.Running = false; state.Step = 0; state.SpeedMultiplier = 1; state.OfflineTrucks.Clear(); break;
                case "step": state.Step++; break;
                case "offline" when command.TruckId.HasValue: state.OfflineTrucks.Add(command.TruckId.Value); break;
                case "online" when command.TruckId.HasValue: state.OfflineTrucks.Remove(command.TruckId.Value); break;
                case "speed" when command.SpeedMultiplier is > 0 and <= 20: state.SpeedMultiplier = command.SpeedMultiplier.Value; break;
                default: throw new DomainRuleException("Simulator command is invalid.", "INVALID_SIMULATOR_COMMAND");
            }
            return new(true, state.Running, state.SpeedMultiplier, state.Step);
        }
    }

    private static TrackingSample Sample(Guid truckId, int index, CompanySimulation state, DateTimeOffset now)
    {
        var routeStep = (state.Step + index * 7) % 100;
        var progress = routeStep / 100m;
        var latitude = 39.9208m + (41.0082m - 39.9208m) * progress + index * 0.002m;
        var longitude = 32.8541m + (28.9784m - 32.8541m) * progress + index * 0.002m;
        var online = !state.OfflineTrucks.Contains(truckId);
        return new(truckId, decimal.Round(latitude, 6), decimal.Round(longitude, 6),
            online && state.Running ? (decimal)(65 * state.SpeedMultiplier) : 0,
            300, online, now, "Simulator");
    }
}

internal sealed class UnconfiguredTrackingProvider : ITrackingProvider
{
    public bool IsSimulator => false;
    public IReadOnlyList<TrackingSample> GetCurrent(Guid companyId, IReadOnlyCollection<Guid> truckIds, DateTimeOffset now) => [];
    public SimulatorState Control(Guid companyId, IReadOnlyCollection<Guid> truckIds, SimulatorCommand command, DateTimeOffset now) =>
        new(false, false, 1, 0);
}
