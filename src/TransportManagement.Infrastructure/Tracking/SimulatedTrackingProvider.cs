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
        public string? RouteRevision { get; set; }
        public decimal AnchorDistanceMeters { get; set; }
        public DateTimeOffset AnchorAt { get; set; }
        public bool Offline { get; set; }
    }

    private sealed class CompanySimulation
    {
        public bool Running { get; set; }
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
                .Where(x => x.Route.Count >= 2 && !string.IsNullOrWhiteSpace(x.RouteRevision))
                .Select(target => Sample(target, StateFor(company, target, now), company, now))
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
            var states = targets.Where(x => x.Route.Count >= 2 && x.RouteRevision is not null)
                .ToDictionary(x => x, x => StateFor(company, x, now));
            foreach (var item in states) Anchor(item.Key, item.Value, company, now);

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
                    foreach (var state in states.Values)
                    {
                        state.AnchorDistanceMeters = 0;
                        state.AnchorAt = now;
                        state.Offline = false;
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
        var length = RouteGeometry.DistanceMeters(target.Route);
        var distance = CurrentDistance(target, state, company, now);
        var position = RouteGeometry.Interpolate(target.Route, distance);
        var arrived = distance >= length;
        var moving = company.Running && target.CanMove && !state.Offline && !arrived;
        return new(target.TruckId,
            decimal.Round(position.Coordinate.Latitude, 6),
            decimal.Round(position.Coordinate.Longitude, 6),
            moving ? _speedKilometersPerHour * (decimal)company.SpeedMultiplier : 0,
            position.Heading, !state.Offline, now, "RouteSimulator");
    }

    private static TruckSimulation StateFor(CompanySimulation company, TrackingTarget target, DateTimeOffset now)
    {
        if (!company.Trucks.TryGetValue(target.TruckId, out var state))
        {
            state = new TruckSimulation { RouteRevision = target.RouteRevision, AnchorAt = now };
            company.Trucks[target.TruckId] = state;
        }
        else if (!string.Equals(state.RouteRevision, target.RouteRevision, StringComparison.Ordinal))
        {
            state.RouteRevision = target.RouteRevision;
            state.AnchorDistanceMeters = 0;
            state.AnchorAt = now;
        }
        return state;
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
