using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Tracking;

/// <summary>The single write boundary for provider telemetry and its side effects.</summary>
public sealed class TrackingIngestionService(
    ITrackingProvider provider,
    ITrackingStore trackingStore,
    IFleetStore fleetStore,
    ITripQueryStore tripStore,
    ICurrentUser currentUser,
    IClock clock,
    TrackingPolicy policy,
    GeofenceEvaluationService geofences,
    INotificationStore notifications)
{
    public async Task TickAsync(CancellationToken cancellationToken)
    {
        if (currentUser.CompanyId == Guid.Empty)
            throw new InvalidOperationException("Tracking ingestion requires an explicit company scope.");
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        var latestByTruck = latest.ToDictionary(x => x.TruckId);
        var targets = BuildTargets(trucks.Select(x => x.Id), trips, latestByTruck);
        var samples = provider.GetCurrent(currentUser.CompanyId, targets, clock.UtcNow);
        var targetsByTruck = targets.ToDictionary(x => x.TruckId);
        var changed = samples
            .Where(sample => targetsByTruck.ContainsKey(sample.TruckId))
            .Where(sample => !latestByTruck.TryGetValue(sample.TruckId, out var previous)
                || ShouldPersist(sample, targetsByTruck[sample.TruckId], previous))
            .Select(sample => Position(sample, targetsByTruck[sample.TruckId]))
            .ToArray();
        if (changed.Length > 0)
        {
            trackingStore.AddPositions(changed);
            await trackingStore.SaveChangesAsync(cancellationToken);
            foreach (var position in changed.Where(x => x.TripId.HasValue))
                await geofences.EvaluateAsync(position, cancellationToken);
            latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        }
        await AddHealthNotificationsAsync(latest, trucks, trips, cancellationToken);
    }

    public async Task<IReadOnlyCollection<TrackingTarget>> TargetsAsync(
        CancellationToken cancellationToken)
    {
        var trucks = await fleetStore.ListTrucksAsync(null, true, null, null, cancellationToken);
        var trips = await tripStore.ListTripsAsync(null, null, null, null, null, null, cancellationToken);
        var latest = await trackingStore.LatestPositionsAsync(cancellationToken);
        return BuildTargets(trucks.Select(x => x.Id), trips, latest.ToDictionary(x => x.TruckId));
    }

    private TruckPosition Position(TrackingSample sample, TrackingTarget target) => new(
        Guid.NewGuid(), currentUser.CompanyId, sample.TruckId, sample.Latitude,
        sample.Longitude, sample.Speed, sample.Heading, sample.IsOnline,
        sample.RecordedAt, sample.Source, target.TripId, target.RoutePlanId,
        sample.TrackingRunId, target.MovementPhase, target.RepositioningPlanId);

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
            || target.TripId != previous.TripId || target.RoutePlanId != previous.RoutePlanId
            || sample.TrackingRunId != previous.TrackingRunId
            || target.MovementPhase != previous.MovementPhase
            || target.RepositioningPlanId != previous.RepositioningPlanId
            || sample.RecordedAt - previous.RecordedAt >=
                (provider.IsSimulator ? policy.SimulatorHeartbeat ?? policy.HistoryHeartbeat : policy.HistoryHeartbeat);
    }

    private async Task AddHealthNotificationsAsync(IReadOnlyList<TruckPosition> latest,
        IReadOnlyList<Domain.Fleet.Truck> trucks, IReadOnlyList<Trip> trips,
        CancellationToken cancellationToken)
    {
        var positions = latest.ToDictionary(x => x.TruckId);
        var trucksById = trucks.ToDictionary(x => x.Id);
        var changed = false;
        foreach (var trip in trips.Where(x => x.ReservesResources && x.TruckId.HasValue))
        {
            var truckId = trip.TruckId!.Value;
            if (!positions.TryGetValue(truckId, out var position)) continue;
            var stale = position.IsOnline && clock.UtcNow - position.RecordedAt > policy.OfflineThreshold;
            if (!stale && position.IsOnline) continue;
            var type = position.IsOnline ? "TruckPositionBecameStale" : "TruckBecameOffline";
            var eventKey = $"{type}:{trip.Id:N}:{position.Id:N}";
            if (await notifications.EventExistsAsync(eventKey, cancellationToken)) continue;
            trucksById.TryGetValue(truckId, out var truck);
            notifications.Add(new OperationNotification(Guid.NewGuid(), currentUser.CompanyId,
                type, position.IsOnline ? "Warning" : "Critical", trip.Id, truckId,
                trip.DriverId, eventKey, JsonSerializer.Serialize(new
                { trip.TripNumber, truck?.PlateNumber, position.RecordedAt }), clock.UtcNow));
            changed = true;
        }
        if (changed) await notifications.SaveChangesAsync(cancellationToken);
    }

    private TrackingTarget[] BuildTargets(IEnumerable<Guid> truckIds, IReadOnlyList<Trip> trips,
        Dictionary<Guid, TruckPosition> latestByTruck) => truckIds.Select(truckId =>
    {
        var trip = trips.FirstOrDefault(x => x.TruckId == truckId && x.ReservesResources && x.RoutePlan is not null);
        var approach = trip?.CurrentRepositioningPlan;
        var isApproach = trip?.Status == TripStatus.EnRouteToPickup;
        var hasApproach = isApproach && approach?.Status == RepositioningPlanStatus.Active;
        var isCargo = trip?.Status is TripStatus.Started or TripStatus.InTransit;
        IReadOnlyList<GeoCoordinate> route = hasApproach
            ? RouteGeometry.FromGeoJson(approach!.Geometry)
            : isCargo && trip?.RoutePlan is not null ? RouteGeometry.FromGeoJson(trip.RoutePlan.Geometry) : [];
        latestByTruck.TryGetValue(truckId, out var latest);
        var stationary = trip?.Status is TripStatus.AtPickup or TripStatus.AtDelivery or TripStatus.Delivered;
        var phase = isApproach ? MovementPhase.Repositioning : isCargo ? MovementPhase.Cargo
            : stationary ? latest?.MovementPhase : MovementPhase.CurrentLocation;
        return new TrackingTarget(truckId,
            isApproach || isCargo ? trip?.Id : stationary ? latest?.TripId : null,
            isCargo ? trip?.RoutePlan?.Id : stationary ? latest?.RoutePlanId : null,
            hasApproach ? $"approach:{approach!.Id:N}" : isCargo ? $"cargo:{trip!.RoutePlan!.StopsFingerprint}" : null,
            route, hasApproach || isCargo, phase,
            hasApproach ? approach!.Id : stationary ? latest?.RepositioningPlanId : null,
            latest is null ? null : new(latest.Latitude, latest.Longitude),
            policy.SimulatorRestoreProjectionToleranceMeters, latest?.IsOnline ?? true,
            latest?.Heading ?? 0, latest is not null &&
                (latest.Source.StartsWith("Simulator", StringComparison.Ordinal)
                 || latest.Source == "RouteSimulator"), latest?.TrackingRunId);
    }).ToArray();
}
