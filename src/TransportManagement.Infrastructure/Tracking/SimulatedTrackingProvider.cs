using System.Collections.Concurrent;
using Microsoft.Extensions.Configuration;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Common;

namespace TransportManagement.Infrastructure.Tracking;

public sealed class SimulatedTrackingProvider(IConfiguration configuration) : ITrackingProvider
{
    private sealed class TruckSimulation
    {
        public Guid? TripId { get; set; }
        public string? RouteRevision { get; set; }
        public decimal AnchorDistanceMeters { get; set; }
        public DateTimeOffset AnchorAt { get; set; }
        public bool Offline { get; set; }
        public Guid RunId { get; set; } = Guid.NewGuid();
        public bool CanEmit { get; set; }
    }

    private sealed class CompanySimulation
    {
        public bool Running { get; set; } = true;
        public double SpeedMultiplier { get; set; } = 1;
        public int Step { get; set; }
        public Dictionary<Guid, TruckSimulation> Trucks { get; } = [];
    }

    private readonly ConcurrentDictionary<Guid, CompanySimulation> _states = new();
    private readonly decimal _speedKilometersPerHour = Math.Clamp(
        configuration.GetValue<decimal>("Tracking:SimulatorSpeedKilometersPerHour", 65), 1, 140);
    private readonly decimal _stepDistanceMeters = Math.Clamp(
        configuration.GetValue<decimal>("Tracking:SimulatorStepDistanceMeters", 1000), 10, 100_000);
    public bool IsSimulator => true;

    public IReadOnlyList<TrackingSample> GetCurrent(
        Guid companyId, IReadOnlyCollection<TrackingTarget> targets, DateTimeOffset now)
    {
        var company = _states.GetOrAdd(companyId, _ => new());
        lock (company)
        {
            return targets.OrderBy(x => x.TruckId)
                .Where(x => x.CanMove && x.Route.Count >= 2 &&
                    !string.IsNullOrWhiteSpace(x.RouteRevision) ||
                    x.RestorePosition is not null && x.HeartbeatEligible)
                .Select(target => (Target: target, State: StateFor(company, target, now)))
                .Where(item => !item.Target.CanMove || item.State.CanEmit)
                .Select(item => Sample(item.Target, item.State, company, now))
                .ToArray();
        }
    }

    public SimulatorState Control(
        Guid companyId,
        IReadOnlyCollection<TrackingTarget> targets,
        SimulatorCommand command,
        DateTimeOffset now)
    {
        var company = _states.GetOrAdd(companyId, _ => new());
        lock (company)
        {
            var states = targets
                .ToDictionary(x => x, x => StateFor(company, x, now));
            foreach (var item in states.Where(x => x.Key.CanMove))
                Anchor(item.Key, item.Value, company, now);

            switch (command.Action.Trim().ToLowerInvariant())
            {
                case "start":
                    company.Running = true;
                    foreach (var state in states.Values) state.Offline = false;
                    break;
                case "pause": company.Running = false; break;
                case "resume": company.Running = true; break;
                case "stop":
                    company.Running = false;
                    foreach (var state in states.Values) state.Offline = true;
                    break;
                case "reset":
                    company.Running = false;
                    company.Step = 0;
                    company.SpeedMultiplier = 1;
                    foreach (var item in states)
                    {
                        if (item.Key.CanMove)
                            item.Value.AnchorDistanceMeters = CurrentDistance(
                                item.Key, item.Value, company, now);
                        item.Value.AnchorAt = now;
                        item.Value.Offline = false;
                        item.Value.RunId = Guid.NewGuid();
                    }
                    break;
                case "step":
                    company.Step++;
                    foreach (var item in states.Where(x => x.Key.CanMove))
                    {
                        var length = RouteGeometry.DistanceMeters(item.Key.Route);
                        item.Value.AnchorDistanceMeters = Math.Min(length,
                            item.Value.AnchorDistanceMeters + _stepDistanceMeters * (decimal)company.SpeedMultiplier);
                        item.Value.AnchorAt = now;
                    }
                    break;
                case "offline" when command.TruckId.HasValue:
                    RequiredTruckState(states, command.TruckId.Value).Offline = true;
                    break;
                case "online" when command.TruckId.HasValue:
                    RequiredTruckState(states, command.TruckId.Value).Offline = false;
                    break;
                case "speed" when command.SpeedMultiplier is > 0 and <= 20:
                    company.SpeedMultiplier = command.SpeedMultiplier.Value;
                    break;
                default:
                    throw new DomainRuleException("Simulator command is invalid.", "INVALID_SIMULATOR_COMMAND");
            }
            foreach (var state in states.Values) state.AnchorAt = now;
            return new(true, company.Running, company.SpeedMultiplier, company.Step);
        }
    }

    private TrackingSample Sample(TrackingTarget target, TruckSimulation state, CompanySimulation company, DateTimeOffset now)
    {
        if (!target.CanMove || target.Route.Count < 2 || target.RouteRevision is null)
        {
            var restored = target.RestorePosition!;
            return new(target.TruckId, restored.Latitude, restored.Longitude, 0,
                target.RestoreHeading, !state.Offline, now,
                "SimulatorHeartbeat", state.RunId);
        }
        var length = RouteGeometry.DistanceMeters(target.Route);
        var distance = CurrentDistance(target, state, company, now);
        var position = RouteGeometry.Interpolate(target.Route, distance);
        var arrived = distance >= length;
        var moving = company.Running && target.CanMove && !state.Offline && !arrived;
        return new(target.TruckId,
            decimal.Round(position.Coordinate.Latitude, 6),
            decimal.Round(position.Coordinate.Longitude, 6),
            moving ? _speedKilometersPerHour : 0,
            position.Heading, !state.Offline, now, "RouteSimulator", state.RunId);
    }

    private static TruckSimulation StateFor(CompanySimulation company, TrackingTarget target, DateTimeOffset now)
    {
        if (!company.Trucks.TryGetValue(target.TruckId, out var state))
        {
            state = new TruckSimulation
            {
                TripId = target.TripId,
                RouteRevision = target.RouteRevision,
                AnchorAt = now,
                Offline = !target.RestoreIsOnline,
                RunId = target.RestoreTrackingRunId ?? Guid.NewGuid(),
                CanEmit = TryRestore(target, out var restoredDistance),
                AnchorDistanceMeters = restoredDistance
            };
            company.Trucks[target.TruckId] = state;
        }
        else if (state.TripId != target.TripId
            || !string.Equals(state.RouteRevision, target.RouteRevision, StringComparison.Ordinal))
        {
            var beginsMovingLeg = target.CanMove && target.Route.Count >= 2
                && target.RouteRevision is not null;
            state.TripId = target.TripId;
            state.RouteRevision = target.RouteRevision;
            state.CanEmit = TryRestore(target, out var restoredDistance);
            state.AnchorDistanceMeters = restoredDistance;
            state.AnchorAt = now;
            if (beginsMovingLeg) state.RunId = Guid.NewGuid();
        }
        return state;
    }

    private static bool TryRestore(TrackingTarget target, out decimal distance)
    {
        distance = 0;
        if (target.Route.Count < 2) return false;
        if (target.RestorePosition is null) return true;
        var projection = RouteGeometry.Project(target.Route, target.RestorePosition);
        if (projection.DistanceFromRouteMeters > target.RestoreProjectionToleranceMeters)
            return false;
        distance = projection.DistanceAlongRouteMeters;
        return true;
    }

    private void Anchor(TrackingTarget target, TruckSimulation state, CompanySimulation company, DateTimeOffset now)
    {
        state.AnchorDistanceMeters = CurrentDistance(target, state, company, now);
        state.AnchorAt = now;
    }

    private decimal CurrentDistance(TrackingTarget target, TruckSimulation state, CompanySimulation company, DateTimeOffset now)
    {
        var length = RouteGeometry.DistanceMeters(target.Route);
        if (!company.Running || !target.CanMove || state.Offline) return Math.Min(length, state.AnchorDistanceMeters);
        var elapsedSeconds = Math.Max(0, (decimal)(now - state.AnchorAt).TotalSeconds);
        var speedMetersPerSecond = _speedKilometersPerHour * 1000 / 3600 * (decimal)company.SpeedMultiplier;
        return Math.Min(length, state.AnchorDistanceMeters + elapsedSeconds * speedMetersPerSecond);
    }

    private static TruckSimulation RequiredTruckState(
        IReadOnlyDictionary<TrackingTarget, TruckSimulation> states, Guid truckId) =>
        states.FirstOrDefault(x => x.Key.TruckId == truckId).Value
        ?? throw new DomainRuleException("The selected truck has no route-aware trip.", "SIMULATOR_ROUTE_REQUIRED");
}

internal sealed class UnconfiguredTrackingProvider : ITrackingProvider
{
    public bool IsSimulator => false;
    public IReadOnlyList<TrackingSample> GetCurrent(Guid companyId, IReadOnlyCollection<TrackingTarget> targets, DateTimeOffset now) => [];
    public SimulatorState Control(Guid companyId, IReadOnlyCollection<TrackingTarget> targets, SimulatorCommand command, DateTimeOffset now) =>
        new(false, false, 1, 0);
}
