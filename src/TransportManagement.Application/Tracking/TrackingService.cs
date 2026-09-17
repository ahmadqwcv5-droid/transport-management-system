using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Tracking;

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
        var samples = provider.GetCurrent(currentUser.CompanyId, trucks.Select(x => x.Id).ToArray(), clock.UtcNow);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        if (samples.Count > 0)
        {
            var latestByTruck = latest.ToDictionary(position => position.TruckId);
            var changed = samples
                .Where(sample => !latestByTruck.TryGetValue(sample.TruckId, out var previous)
                    || ShouldPersist(sample, previous))
                .Select(sample => new TruckPosition(
                    Guid.NewGuid(), currentUser.CompanyId, sample.TruckId, sample.Latitude,
                    sample.Longitude, sample.Speed, sample.Heading, sample.IsOnline,
                    sample.RecordedAt, sample.Source))
                .ToArray();
            if (changed.Length > 0)
            {
                trackingStore.AddPositions(changed);
                await trackingStore.SaveChangesAsync(cancellationToken);
                latest = await trackingStore.LatestPositionsAsync(cancellationToken);
            }
        }
        var trips = await operationsStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
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

    public async Task<SimulatorStateResponse> ControlAsync(SimulatorControlRequest request, CancellationToken cancellationToken)
    {
        if (!provider.IsSimulator)
            throw new ConflictException("The tracking simulator is disabled.", "SIMULATOR_DISABLED");
        var trucks = await operationsStore.ListTrucksAsync(null, true, null, cancellationToken);
        if (request.TruckId.HasValue && trucks.All(x => x.Id != request.TruckId.Value))
            throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");
        var state = provider.Control(currentUser.CompanyId, trucks.Select(x => x.Id).ToArray(),
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

    private bool ShouldPersist(TrackingSample sample, TruckPosition previous)
    {
        var headingDelta = Math.Abs(sample.Heading - previous.Heading);
        headingDelta = Math.Min(headingDelta, 360 - headingDelta);
        return Math.Abs(sample.Latitude - previous.Latitude) > policy.CoordinateTolerance
            || Math.Abs(sample.Longitude - previous.Longitude) > policy.CoordinateTolerance
            || Math.Abs(sample.Speed - previous.Speed) > policy.SpeedTolerance
            || headingDelta > policy.HeadingTolerance
            || sample.IsOnline != previous.IsOnline
            || !string.Equals(sample.Source, previous.Source, StringComparison.Ordinal)
            || sample.RecordedAt - previous.RecordedAt >= policy.HistoryHeartbeat;
    }
}
