using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Dashboard;

public sealed class ActiveOperationsService(
    IActiveOperationsStore operations,
    IClock clock,
    TrackingPolicy trackingPolicy,
    RouteProgressPolicy progressPolicy)
{
    public async Task<ActiveOperationsResponse> QueryAsync(
        ActiveOperationsQuery query, CancellationToken cancellationToken)
    {
        if (query.Limit is < 1 or > 100)
            throw new DomainRuleException(
                "Active operation limit must be between 1 and 100.",
                "INVALID_ACTIVE_OPERATION_LIMIT");

        var now = clock.UtcNow;
        var source = await operations.QueryAsync(query,
            Math.Clamp(query.Limit * 5, 100, 500), cancellationToken);
        IEnumerable<ActiveTripOperationalResponse> result = source.Items
            .Select(item => Project(item, now));
        if (query.AttentionOnly)
            result = result.Where(x => x.AttentionCode != "NONE");

        var ordered = result.OrderBy(x => x.AttentionPriority)
            .ThenBy(x => x.EstimatedArrivalAt ?? DateTimeOffset.MaxValue)
            .ThenBy(x => x.TripNumber)
            .ToArray();
        return new(ordered.Take(query.Limit).ToArray(),
            query.AttentionOnly ? ordered.Length : source.TotalCount, now);
    }

    private ActiveTripOperationalResponse Project(
        ActiveOperationSource trip, DateTimeOffset now)
    {
        var (phase, milestone, stop, waiting) = Phase(trip);
        var health = trip.PositionRecordedAt is null ? "NoTelemetry"
            : trip.IsOnline != true ? "Offline"
            : now - trip.PositionRecordedAt > trackingPolicy.OfflineThreshold
                ? "Stale" : "Current";
        decimal? progress = null;
        decimal? remaining = null;
        DateTimeOffset? eta = null;
        bool? offRoute = null;
        var route = trip.Status == TripStatus.EnRouteToPickup
            ? trip.ApproachRouteGeometry
            : trip.Status is TripStatus.Started or TripStatus.InTransit
                ? trip.CargoRouteGeometry : null;
        var distance = trip.Status == TripStatus.EnRouteToPickup
            ? trip.ApproachRouteDistanceMeters
            : trip.Status is TripStatus.Started or TripStatus.InTransit
                ? trip.CargoRouteDistanceMeters : null;
        var usablePosition = trip.Latitude.HasValue && trip.Longitude.HasValue
            && trip.PositionTripId == trip.TripId && health == "Current";
        if (route is not null && distance is > 0 && usablePosition)
        {
            var projection = RouteGeometry.Project(RouteGeometry.FromGeoJson(route),
                new(trip.Latitude!.Value, trip.Longitude!.Value));
            var travelled = Math.Clamp(projection.DistanceAlongRouteMeters, 0, distance.Value);
            remaining = Math.Max(0, distance.Value - travelled);
            progress = decimal.Round(Math.Clamp(travelled / distance.Value * 100, 0, 100), 1);
            offRoute = projection.DistanceFromRouteMeters > progressPolicy.OffRouteThresholdMeters;
            if (trip.Speed > 0.5m)
                eta = now.AddSeconds((double)(remaining.Value / (trip.Speed.Value * 1000 / 3600)));
        }

        var attention = offRoute == true ? "OFF_ROUTE"
            : health == "Offline" ? "TRACKING_OFFLINE"
            : health == "Stale" ? "TRACKING_STALE"
            : health == "NoTelemetry" && trip.Status != TripStatus.Assigned
                ? "TRACKING_MISSING"
            : trip.Status == TripStatus.Assigned ? "AWAITING_DRIVER_DEPARTURE"
            : trip.Status == TripStatus.AtPickup ? "AWAITING_LOADING_CONFIRMATION"
            : trip.Status == TripStatus.AtDelivery ? "AWAITING_DELIVERY_CONFIRMATION"
            : "NONE";
        var priority = attention switch
        {
            "OFF_ROUTE" => 0,
            "TRACKING_OFFLINE" => 1,
            "TRACKING_STALE" => 2,
            "TRACKING_MISSING" => 3,
            "AWAITING_DELIVERY_CONFIRMATION" => 4,
            "AWAITING_LOADING_CONFIRMATION" => 5,
            "AWAITING_DRIVER_DEPARTURE" => 6,
            _ => 10
        };
        return new(trip.TripId, trip.TripNumber, trip.ClientId, trip.ClientName,
            trip.TruckId, trip.TruckPlateNumber, trip.TruckFleetCode,
            trip.TruckPhotoVersion,
            trip.TruckPhotoVersion is null || trip.TruckId is null ? null
                : $"/api/trucks/{trip.TruckId}/photo/thumbnail?v={trip.TruckPhotoVersion}",
            trip.DriverId, trip.DriverName, trip.Status.ToString(), phase,
            milestone, stop, progress, remaining, eta,
            trip.PositionRecordedAt, health, trip.IsOnline, offRoute,
            attention, priority, waiting ? trip.UpdatedAt : null);
    }

    private static (string Phase, string Milestone, string? Stop, bool Waiting) Phase(
        ActiveOperationSource trip) => trip.Status switch
    {
        TripStatus.Assigned => ("AwaitingDeparture", "DriverDeparture", trip.PickupName, true),
        TripStatus.EnRouteToPickup => ("ToPickup", "Pickup", trip.PickupName, false),
        TripStatus.AtPickup => ("AwaitingLoading", "LoadingConfirmation", trip.PickupName, true),
        TripStatus.Started or TripStatus.InTransit => ("ToDelivery", "Delivery", trip.DeliveryName, false),
        TripStatus.AtDelivery => ("AwaitingDeliveryConfirmation", "DeliveryConfirmation", trip.DeliveryName, true),
        TripStatus.Delivered => ("AwaitingCompletion", "Completion", trip.DeliveryName, true),
        _ => (trip.Status.ToString(), trip.Status.ToString(), null, false)
    };
}
