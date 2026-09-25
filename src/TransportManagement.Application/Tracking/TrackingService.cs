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
    IFleetStore fleetStore,
    ITruckPhotoStore photoStore,
    ITripQueryStore tripStore,
    ICurrentUser currentUser,
    IClock clock,
    TrackingPolicy policy,
    DispatchPolicy dispatchPolicy,
    TrackingIngestionService ingestion)
{
    public async Task<IReadOnlyList<TruckPositionResponse>> CurrentAsync(CancellationToken cancellationToken)
    {
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        var drivers = await fleetStore.ListDriversAsync(null, null, null, cancellationToken);
        var photos = (await photoStore.ListAsync(cancellationToken)).ToDictionary(x => x.TruckId);
        return latest.Join(trucks, p => p.TruckId, t => t.Id,
            (p, t) => Map(p, t.PlateNumber, t.Status.ToString(), trips, drivers,
                photos.GetValueOrDefault(t.Id))).ToArray();
    }

    public async Task<TruckPositionResponse> CurrentForTruckAsync(Guid truckId, CancellationToken cancellationToken)
    {
        var truck = await fleetStore.GetTruckAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        var position = await trackingStore.LatestPositionAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("No tracking position is available.", "POSITION_NOT_FOUND");
        var trips = await tripStore.ListTripsAsync(null, null, truckId, null, null, null, cancellationToken);
        var drivers = await fleetStore.ListDriversAsync(null, null, null, cancellationToken);
        return Map(position, truck.PlateNumber, truck.Status.ToString(), trips, drivers,
            await photoStore.GetAsync(truckId, cancellationToken));
    }

    public async Task<IReadOnlyList<TruckPositionResponse>> HistoryAsync(Guid truckId, int limit, CancellationToken cancellationToken)
    {
        var truck = await fleetStore.GetTruckAsync(truckId, cancellationToken)
            ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        var trips = await tripStore.ListTripsAsync(null, null, truckId, null, null, null, cancellationToken);
        var drivers = await fleetStore.ListDriversAsync(null, null, null, cancellationToken);
        return (await trackingStore.HistoryAsync(truckId, Math.Clamp(limit, 1, 200), cancellationToken))
            .Select(p => Map(p, truck.PlateNumber, truck.Status.ToString(), trips, drivers,
                null)).ToArray();
    }

    public async Task<TripTrackingHistoryResponse> TripHistoryAsync(
        Guid tripId, int limit, CancellationToken cancellationToken)
    {
        var trip = await tripStore.GetTripAsync(tripId, cancellationToken)
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
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
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
            var seededTrips = await tripStore.ListTripsAsync(
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
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        var state = provider.Control(currentUser.CompanyId, BuildTargets(
                trucks.Select(x => x.Id), trips, latest.ToDictionary(x => x.TruckId)),
            new SimulatorCommand(request.Action, request.TruckId, request.SpeedMultiplier), clock.UtcNow);
        await ingestion.TickAsync(cancellationToken);
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
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
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
        IReadOnlyList<Domain.Trips.Trip> trips, IReadOnlyList<Domain.Fleet.Driver> drivers,
        Domain.Fleet.TruckPhoto? photo)
    {
        var trip = trips.FirstOrDefault(x => x.TruckId == position.TruckId && x.ReservesResources);
        var driver = trip?.DriverId is Guid driverId ? drivers.FirstOrDefault(x => x.Id == driverId) : null;
        var isOnline = position.IsOnline && clock.UtcNow - position.RecordedAt <= policy.OfflineThreshold;
        return new(position.TruckId, plate, status, position.Latitude, position.Longitude,
            position.Speed, position.Heading, position.RecordedAt, isOnline,
            isOnline ? "Online" : "Offline", trip?.Id, driver?.FullName,
            position.MovementPhase, position.RepositioningPlanId,
            photo?.Version, photo is null ? null
                : $"/api/trucks/{position.TruckId}/photo/thumbnail?v={photo.Version}");
    }

    private TrackingTarget[] BuildTargets(
        IEnumerable<Guid> truckIds, IReadOnlyList<Trip> trips,
        Dictionary<Guid, TruckPosition> latestByTruck) =>
        truckIds.Select(truckId =>
        {
            var trip = trips.FirstOrDefault(x => x.TruckId == truckId && x.ReservesResources && x.RoutePlan is not null);
            var approach = trip?.CurrentRepositioningPlan;
            var isApproach = trip?.Status == TripStatus.EnRouteToPickup;
            var hasApproachRoute = isApproach
                && approach?.Status == RepositioningPlanStatus.Active;
            var isCargo = trip?.Status is TripStatus.Started or TripStatus.InTransit;
            IReadOnlyList<GeoCoordinate> coordinates = hasApproachRoute
                ? RouteGeometry.FromGeoJson(approach!.Geometry)
                : isCargo && trip?.RoutePlan is not null
                    ? RouteGeometry.FromGeoJson(trip.RoutePlan.Geometry)
                    : [];
            latestByTruck.TryGetValue(truckId, out var latest);
            var retainStationaryContext = trip?.Status is TripStatus.AtPickup
                or TripStatus.AtDelivery or TripStatus.Delivered;
            var phase = isApproach ? MovementPhase.Repositioning
                : isCargo ? MovementPhase.Cargo
                : retainStationaryContext ? latest?.MovementPhase : MovementPhase.CurrentLocation;
            var targetTripId = isApproach || isCargo ? trip?.Id
                : retainStationaryContext ? latest?.TripId : null;
            var targetRouteId = isCargo ? trip?.RoutePlan?.Id
                : retainStationaryContext ? latest?.RoutePlanId : null;
            var targetApproachId = hasApproachRoute ? approach!.Id
                : retainStationaryContext ? latest?.RepositioningPlanId : null;
            return new TrackingTarget(
                truckId,
                targetTripId,
                targetRouteId,
                hasApproachRoute ? $"approach:{approach!.Id:N}" : isCargo
                    ? $"cargo:{trip!.RoutePlan!.StopsFingerprint}" : null,
                coordinates,
                hasApproachRoute || isCargo,
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
