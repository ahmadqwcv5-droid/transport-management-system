using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Tracking;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Tracking;

public sealed class TrackingService(
    ITrackingProvider provider,
    ITrackingStore trackingStore,
    IOperationsStore operationsStore,
    ICurrentUser currentUser,
    IClock clock,
    TrackingPolicy policy)
{
    public async Task<IReadOnlyList<TruckPositionResponse>> CurrentAsync(CancellationToken cancellationToken)
    {
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var targets = BuildTargets(trucks.Select(x => x.Id), trips);
        var samples = provider.GetCurrent(currentUser.CompanyId, targets, clock.UtcNow);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        if (samples.Count > 0)
        {
            var latestByTruck = latest.ToDictionary(position => position.TruckId);
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
                        sample.TrackingRunId);
                })
                .ToArray();
            if (changed.Length > 0)
            {
                trackingStore.AddPositions(changed);
                await trackingStore.SaveChangesAsync(cancellationToken);
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
                var id = $"{first.TrackingRunId:N}:{first.RoutePlanId:N}:{first.Id:N}";
                return new TripTrailSegmentResponse(
                    id,
                    first.TrackingRunId!.Value,
                    first.RoutePlanId,
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
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var state = provider.Control(currentUser.CompanyId, BuildTargets(trucks.Select(x => x.Id), trips),
            new SimulatorCommand(request.Action, request.TruckId, request.SpeedMultiplier), clock.UtcNow);
        return new(state.Enabled, state.Running, state.SpeedMultiplier, state.Step);
    }

    private TruckPositionResponse Map(TruckPosition position, string plate, string status,
        IReadOnlyList<Domain.Trips.Trip> trips, IReadOnlyList<Domain.Fleet.Driver> drivers)
    {
        var trip = trips.FirstOrDefault(x => x.TruckId == position.TruckId && x.ReservesResources);
        var driver = trip?.DriverId is Guid driverId ? drivers.FirstOrDefault(x => x.Id == driverId) : null;
        var isOnline = position.IsOnline && clock.UtcNow - position.RecordedAt <= policy.OfflineThreshold;
        return new(position.TruckId, plate, status, position.Latitude, position.Longitude,
            position.Speed, position.Heading, position.RecordedAt, isOnline,
            isOnline ? "Online" : "Offline", trip?.Id, driver?.FullName);
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
            || sample.RecordedAt - previous.RecordedAt >= policy.HistoryHeartbeat;
    }

    private static TrackingTarget[] BuildTargets(
        IEnumerable<Guid> truckIds, IReadOnlyList<Trip> trips) =>
        truckIds.Select(truckId =>
        {
            var trip = trips.FirstOrDefault(x => x.TruckId == truckId && x.ReservesResources && x.RoutePlan is not null);
            var coordinates = trip?.RoutePlan is null
                ? (IReadOnlyList<GeoCoordinate>)[]
                : RouteGeometry.FromGeoJson(trip.RoutePlan.Geometry);
            return new TrackingTarget(
                truckId,
                trip?.Id,
                trip?.RoutePlan?.Id,
                trip?.RoutePlan?.StopsFingerprint,
                coordinates,
                trip?.Status is TripStatus.Started or TripStatus.InTransit);
        }).ToArray();
}
