using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Tracking;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Common;

namespace TransportManagement.Application.Tracking;

public sealed class TrackingService(
    ITrackingProvider provider,
    ITrackingStore trackingStore,
    IOperationsStore operationsStore,
    ICurrentUser currentUser,
    IClock clock,
    TrackingPolicy policy,
    DispatchPolicy dispatchPolicy,
    TripService tripService)
{
    public async Task<IReadOnlyList<TruckPositionResponse>> CurrentAsync(CancellationToken cancellationToken)
    {
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        var latestByTruck = latest.ToDictionary(position => position.TruckId);
        var targets = BuildTargets(trucks.Select(x => x.Id), trips, latestByTruck);
        var samples = provider.GetCurrent(currentUser.CompanyId, targets, clock.UtcNow);
        if (samples.Count > 0)
        {
            var targetsByTruck = targets.ToDictionary(target => target.TruckId);
            var changed = samples
                .Where(sample => !latestByTruck.TryGetValue(sample.TruckId, out var previous)
                    || ShouldPersist(sample, targetsByTruck[sample.TruckId], previous))
                .Select(sample =>
                {
                    var target = targetsByTruck[sample.TruckId];
                    return new TruckPosition(
                        Guid.NewGuid(), currentUser.CompanyId, sample.TruckId, sample.Latitude,
                        sample.Longitude, sample.Speed, sample.Heading, sample.IsOnline,
                        sample.RecordedAt, sample.Source, target.TripId, target.RoutePlanId,
                        sample.TrackingRunId, target.MovementPhase, target.RepositioningPlanId);
                })
                .ToArray();
            if (changed.Length > 0)
            {
                trackingStore.AddPositions(changed);
                await trackingStore.SaveChangesAsync(cancellationToken);
                foreach (var position in changed.Where(x =>
                    x.MovementPhase == MovementPhase.Repositioning && x.TripId.HasValue))
                    await tripService.EvaluateArrivalAsync(
                        position.TripId!.Value, position, cancellationToken);
                latest = await trackingStore.LatestPositionsAsync(cancellationToken);
            }
        }
        var drivers = await operationsStore.ListDriversAsync(null, null, null, cancellationToken);
        return latest.Join(trucks, p => p.TruckId, t => t.Id, (p, t) => Map(p, t.PlateNumber, t.Status.ToString(), trips, drivers)).ToArray();
    }

    public async Task<TruckPositionResponse> CurrentForTruckAsync(Guid truckId, CancellationToken cancellationToken)
    {
        var truck = await operationsStore.GetTruckAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        await CurrentAsync(cancellationToken);
        var position = await trackingStore.LatestPositionAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("No tracking position is available.", "POSITION_NOT_FOUND");
        var trips = await operationsStore.ListTripsAsync(null, null, truckId, null, null, null, cancellationToken);
        var drivers = await operationsStore.ListDriversAsync(null, null, null, cancellationToken);
        return Map(position, truck.PlateNumber, truck.Status.ToString(), trips, drivers);
    }

    public async Task<IReadOnlyList<TruckPositionResponse>> HistoryAsync(Guid truckId, int limit, CancellationToken cancellationToken)
    {
        var truck = await operationsStore.GetTruckAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        var trips = await operationsStore.ListTripsAsync(null, null, truckId, null, null, null, cancellationToken);
        var drivers = await operationsStore.ListDriversAsync(null, null, null, cancellationToken);
        return (await trackingStore.HistoryAsync(truckId, Math.Clamp(limit, 1, 200), cancellationToken))
            .Select(p => Map(p, truck.PlateNumber, truck.Status.ToString(), trips, drivers)).ToArray();
    }

    public async Task<TripTrackingHistoryResponse> TripHistoryAsync(
        Guid tripId, int limit, CancellationToken cancellationToken)
    {
        var trip = await operationsStore.GetTripAsync(tripId, cancellationToken)
            ?? throw new NotFoundException("Trip was not found in the current company.", "TRIP_NOT_FOUND");
        if (trip.TruckId is not Guid truckId)
            throw new ConflictException("The trip has no assigned truck.", "TRIP_TRUCK_REQUIRED");
        var boundedLimit = Math.Clamp(limit, 1, policy.MaxTripHistoryPoints);
        var positions = await trackingStore.TripHistoryAsync(
            trip.Id, truckId, boundedLimit, cancellationToken);
        var segments = TrailSegmenter.Segment(
                positions, policy.TrailGapThreshold, policy.TrailJumpThresholdMeters)
            .Select(segment =>
            {
                var first = segment[0];
                var id = $"{first.TrackingRunId:N}:{first.RoutePlanId:N}:{first.RepositioningPlanId:N}:{first.Id:N}";
                return new TripTrailSegmentResponse(
                    id,
                    first.TrackingRunId!.Value,
                    first.RoutePlanId,
                    first.RepositioningPlanId,
                    first.MovementPhase,
                    segment.Select(position => new TripTrailPointResponse(
                        position.Id, position.Latitude, position.Longitude,
                        position.Speed, position.Heading, position.IsOnline,
                        position.RecordedAt, position.Source)).ToArray());
            }).ToArray();
        return new(trip.Id, truckId, segments.Sum(segment => segment.Points.Count), segments);
    }

    public async Task<SimulatorStateResponse> ControlAsync(SimulatorControlRequest request, CancellationToken cancellationToken)
    {
        if (!provider.IsSimulator)
            throw new ConflictException("The tracking simulator is disabled.", "SIMULATOR_DISABLED");
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        if (request.TruckId.HasValue && trucks.All(x => x.Id != request.TruckId.Value))
            throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        if (string.Equals(request.Action, "seed-position", StringComparison.OrdinalIgnoreCase)
            || string.Equals(request.Action, "set-position", StringComparison.OrdinalIgnoreCase))
        {
            if (request.TruckId is not Guid seedTruckId || request.Latitude is not decimal latitude
                || request.Longitude is not decimal longitude)
                throw new DomainRuleException("Seed position requires truck and coordinates.", "INVALID_SIMULATOR_COMMAND");
            var seeded = new TruckPosition(
                Guid.NewGuid(), currentUser.CompanyId, seedTruckId, latitude, longitude,
                0, 0, true, clock.UtcNow, "SimulatorSeed", null, null,
                Guid.NewGuid(), MovementPhase.CurrentLocation);
            trackingStore.AddPositions([seeded]);
            await trackingStore.SaveChangesAsync(cancellationToken);
            var seededLatest = await trackingStore.LatestPositionsAsync(cancellationToken);
            var seededTrips = await operationsStore.ListTripsAsync(
                null, null, null, null, null, null, cancellationToken);
            var seededState = provider.Control(currentUser.CompanyId,
                BuildTargets(trucks.Select(x => x.Id), seededTrips,
                    seededLatest.ToDictionary(x => x.TruckId)),
                new SimulatorCommand("online", seedTruckId), clock.UtcNow);
            return new(seededState.Enabled, seededState.Running,
                seededState.SpeedMultiplier, seededState.Step);
        }
        if (string.Equals(request.Action, "refresh-position", StringComparison.OrdinalIgnoreCase))
        {
            if (request.TruckId is not Guid refreshTruckId)
                throw new DomainRuleException("Refresh position requires a truck.", "INVALID_SIMULATOR_COMMAND");
            var previous = await trackingStore.LatestPositionAsync(refreshTruckId, cancellationToken)
                ?? throw new ConflictException("The truck has no location to refresh.", "TRUCK_POSITION_REQUIRED");
            if (!previous.IsOnline)
                throw new ConflictException("The truck is offline.", "TRUCK_OFFLINE");
            var refreshed = new TruckPosition(
                Guid.NewGuid(), currentUser.CompanyId, refreshTruckId,
                previous.Latitude, previous.Longitude, 0, previous.Heading, true,
                clock.UtcNow, "SimulatorRefresh", null, null, Guid.NewGuid(),
                MovementPhase.CurrentLocation);
            trackingStore.AddPositions([refreshed]);
            await trackingStore.SaveChangesAsync(cancellationToken);
            return new(true, false, 1, 0);
        }
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        var state = provider.Control(currentUser.CompanyId, BuildTargets(
                trucks.Select(x => x.Id), trips, latest.ToDictionary(x => x.TruckId)),
            new SimulatorCommand(request.Action, request.TruckId, request.SpeedMultiplier), clock.UtcNow);
        return new(state.Enabled, state.Running, state.SpeedMultiplier, state.Step);
    }

    public async Task<IReadOnlyList<SimulatorTruckResponse>> SimulatorInventoryAsync(
        bool sampleProvider, CancellationToken cancellationToken)
    {
        if (!provider.IsSimulator)
        {
            if (sampleProvider)
                throw new ConflictException("The tracking simulator is disabled.", "SIMULATOR_DISABLED");
            return [];
        }
        if (sampleProvider) await CurrentAsync(cancellationToken);
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = (await trackingStore.LatestPositionsAsync(cancellationToken))
            .ToDictionary(x => x.TruckId);
        return trucks.OrderBy(x => x.PlateNumber).Select(truck =>
        {
            latest.TryGetValue(truck.Id, out var position);
            var trip = trips.FirstOrDefault(x => x.TruckId == truck.Id && x.ReservesResources);
            var age = position is null ? (TimeSpan?)null : clock.UtcNow - position.RecordedAt;
            var locationState = position is null ? "NoLocation"
                : !position.IsOnline ? "Offline"
                : age > dispatchPolicy.MaximumPositionAge ? "Stale" : "Current";
            return new SimulatorTruckResponse(
                truck.Id, truck.PlateNumber, truck.Status.ToString(), locationState,
                position?.Latitude, position?.Longitude, position?.Heading,
                position?.RecordedAt,
                age is null ? null : Math.Max(0, (int)age.Value.TotalSeconds),
                (int)dispatchPolicy.MaximumPositionAge.TotalSeconds,
                position?.IsOnline, trip?.Id, position?.MovementPhase);
        }).ToArray();
    }

    private TruckPositionResponse Map(TruckPosition position, string plate, string status,
        IReadOnlyList<Domain.Trips.Trip> trips, IReadOnlyList<Domain.Fleet.Driver> drivers)
    {
        var trip = trips.FirstOrDefault(x => x.TruckId == position.TruckId && x.ReservesResources);
        var driver = trip?.DriverId is Guid driverId ? drivers.FirstOrDefault(x => x.Id == driverId) : null;
        var isOnline = position.IsOnline && clock.UtcNow - position.RecordedAt <= policy.OfflineThreshold;
        return new(position.TruckId, plate, status, position.Latitude, position.Longitude,
            position.Speed, position.Heading, position.RecordedAt, isOnline,
            isOnline ? "Online" : "Offline", trip?.Id, driver?.FullName,
            position.MovementPhase, position.RepositioningPlanId);
    }

    private bool ShouldPersist(TrackingSample sample, TrackingTarget target, TruckPosition previous)
    {
        var headingDelta = Math.Abs(sample.Heading - previous.Heading);
        headingDelta = Math.Min(headingDelta, 360 - headingDelta);
        return Math.Abs(sample.Latitude - previous.Latitude) > policy.CoordinateTolerance
            || Math.Abs(sample.Longitude - previous.Longitude) > policy.CoordinateTolerance
            || Math.Abs(sample.Speed - previous.Speed) > policy.SpeedTolerance
            || headingDelta > policy.HeadingTolerance
            || sample.IsOnline != previous.IsOnline
            || !string.Equals(sample.Source, previous.Source, StringComparison.Ordinal)
            || target.TripId != previous.TripId
            || target.RoutePlanId != previous.RoutePlanId
            || sample.TrackingRunId != previous.TrackingRunId
            || target.MovementPhase != previous.MovementPhase
            || target.RepositioningPlanId != previous.RepositioningPlanId
            || sample.RecordedAt - previous.RecordedAt >=
                (provider.IsSimulator
                    ? policy.SimulatorHeartbeat ?? policy.HistoryHeartbeat
                    : policy.HistoryHeartbeat);
    }

    private TrackingTarget[] BuildTargets(
        IEnumerable<Guid> truckIds, IReadOnlyList<Trip> trips,
        Dictionary<Guid, TruckPosition> latestByTruck) =>
        truckIds.Select(truckId =>
        {
            var trip = trips.FirstOrDefault(x => x.TruckId == truckId && x.ReservesResources && x.RoutePlan is not null);
            var approach = trip?.CurrentRepositioningPlan;
            var isApproach = trip?.Status == TripStatus.EnRouteToPickup
                && approach?.Status == RepositioningPlanStatus.Active;
            var isCargo = trip?.Status is TripStatus.Started or TripStatus.InTransit;
            IReadOnlyList<GeoCoordinate> coordinates = isApproach
                ? RouteGeometry.FromGeoJson(approach!.Geometry)
                : isCargo && trip?.RoutePlan is not null
                    ? RouteGeometry.FromGeoJson(trip.RoutePlan.Geometry)
                    : [];
            latestByTruck.TryGetValue(truckId, out var latest);
            var phase = isApproach ? MovementPhase.Repositioning
                : isCargo ? MovementPhase.Cargo : latest?.MovementPhase;
            var targetTripId = isApproach || isCargo ? trip?.Id : latest?.TripId;
            var targetRouteId = isCargo ? trip?.RoutePlan?.Id : latest?.RoutePlanId;
            var targetApproachId = isApproach ? approach!.Id : latest?.RepositioningPlanId;
            return new TrackingTarget(
                truckId,
                targetTripId,
                targetRouteId,
                isApproach ? $"approach:{approach!.Id:N}" : isCargo
                    ? $"cargo:{trip!.RoutePlan!.StopsFingerprint}" : null,
                coordinates,
                isApproach || isCargo,
                phase,
                targetApproachId,
                latest is null ? null : new(latest.Latitude, latest.Longitude),
                policy.SimulatorRestoreProjectionToleranceMeters,
                latest?.IsOnline ?? true,
                latest?.Heading ?? 0,
                latest is not null && (latest.Source.StartsWith("Simulator", StringComparison.Ordinal)
                    || string.Equals(latest.Source, "RouteSimulator", StringComparison.Ordinal)),
                latest?.TrackingRunId);
        }).ToArray();
}
