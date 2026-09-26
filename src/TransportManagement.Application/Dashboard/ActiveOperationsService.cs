using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Tracking;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Dashboard;

public sealed class ActiveOperationsService(
    ITripQueryStore trips,
    IClientStore clients,
    IFleetStore fleet,
    ITruckPhotoStore photos,
    ITrackingStore tracking,
    IClock clock,
    TrackingPolicy trackingPolicy,
    RouteProgressPolicy progressPolicy)
{
    private static readonly TripStatus[] OperationalStatuses =
    [
        TripStatus.Assigned, TripStatus.EnRouteToPickup, TripStatus.AtPickup,
        TripStatus.Started, TripStatus.InTransit, TripStatus.AtDelivery,
        TripStatus.Delivered
    ];

    public async Task<ActiveOperationsResponse> QueryAsync(
        ActiveOperationsQuery query, CancellationToken cancellationToken)
    {
        if (query.Limit is < 1 or > 100)
            throw new DomainRuleException(
                "Active operation limit must be between 1 and 100.",
                "INVALID_ACTIVE_OPERATION_LIMIT");

        var now = clock.UtcNow;
        var allTrips = await trips.ListTripsAsync(
            null, null, null, null, null, null, cancellationToken);
        var active = allTrips.Where(x => !x.IsArchived
            && OperationalStatuses.Contains(x.Status)).ToArray();
        var clientById = (await clients.ListClientsAsync(
            null, null, null, cancellationToken)).ToDictionary(x => x.Id);
        var trucks = (await fleet.ListTrucksAsync(
            null, null, null, null, cancellationToken)).ToDictionary(x => x.Id);
        var drivers = (await fleet.ListDriversAsync(
            null, null, null, cancellationToken)).ToDictionary(x => x.Id);
        var photoByTruck = (await photos.ListAsync(cancellationToken))
            .ToDictionary(x => x.TruckId);
        var positionByTruck = (await tracking.LatestPositionsAsync(cancellationToken))
            .ToDictionary(x => x.TruckId);

        IEnumerable<ActiveTripOperationalResponse> result = active.Select(trip =>
        {
            clientById.TryGetValue(trip.ClientId, out var client);
            var truck = trip.TruckId is Guid truckId
                ? trucks.GetValueOrDefault(truckId) : null;
            var driver = trip.DriverId is Guid driverId
                ? drivers.GetValueOrDefault(driverId) : null;
            var photo = trip.TruckId is Guid photoTruckId
                ? photoByTruck.GetValueOrDefault(photoTruckId) : null;
            var position = trip.TruckId is Guid positionTruckId
                ? positionByTruck.GetValueOrDefault(positionTruckId) : null;
            return Project(trip, client?.Name ?? string.Empty, truck, driver,
                photo, position, now);
        });

        if (query.ClientId.HasValue)
            result = result.Where(x => x.ClientId == query.ClientId.Value);
        if (query.TruckId.HasValue)
            result = result.Where(x => x.TruckId == query.TruckId.Value);
        if (query.DriverId.HasValue)
            result = result.Where(x => x.DriverId == query.DriverId.Value);
        if (!string.IsNullOrWhiteSpace(query.Phase))
            result = result.Where(x => x.OperationalPhase.Equals(
                query.Phase.Trim(), StringComparison.OrdinalIgnoreCase));
        if (query.AttentionOnly)
            result = result.Where(x => x.AttentionCode != "NONE");
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var term = query.Search.Trim();
            result = result.Where(x =>
                x.TripNumber.Contains(term, StringComparison.OrdinalIgnoreCase)
                || x.ClientName.Contains(term, StringComparison.OrdinalIgnoreCase)
                || (x.TruckPlateNumber?.Contains(term, StringComparison.OrdinalIgnoreCase) ?? false)
                || (x.TruckFleetCode?.Contains(term, StringComparison.OrdinalIgnoreCase) ?? false)
                || (x.DriverName?.Contains(term, StringComparison.OrdinalIgnoreCase) ?? false)
                || (x.NextStopName?.Contains(term, StringComparison.OrdinalIgnoreCase) ?? false));
        }

        var ordered = result.OrderBy(x => x.AttentionPriority)
            .ThenBy(x => x.EstimatedArrivalAt ?? DateTimeOffset.MaxValue)
            .ThenBy(x => x.TripNumber)
            .ToArray();
        return new(ordered.Take(query.Limit).ToArray(), ordered.Length, now);
    }

    private ActiveTripOperationalResponse Project(
        Trip trip,
        string clientName,
        Domain.Fleet.Truck? truck,
        Domain.Fleet.Driver? driver,
        Domain.Fleet.TruckPhoto? photo,
        Domain.Tracking.TruckPosition? position,
        DateTimeOffset now)
    {
        var (phase, milestone, stop, waiting) = Phase(trip);
        var health = position is null ? "NoTelemetry"
            : !position.IsOnline ? "Offline"
            : now - position.RecordedAt > trackingPolicy.OfflineThreshold
                ? "Stale" : "Current";
        decimal? progress = null;
        decimal? remaining = null;
        DateTimeOffset? eta = null;
        bool? offRoute = null;
        var route = trip.Status == TripStatus.EnRouteToPickup
            ? trip.CurrentRepositioningPlan?.Geometry
            : trip.Status is TripStatus.Started or TripStatus.InTransit
                ? trip.RoutePlan?.Geometry : null;
        var distance = trip.Status == TripStatus.EnRouteToPickup
            ? trip.CurrentRepositioningPlan?.DistanceMeters
            : trip.Status is TripStatus.Started or TripStatus.InTransit
                ? trip.RoutePlan?.DistanceMeters : null;
        var usablePosition = position is not null && position.TripId == trip.Id
            && health == "Current";
        if (route is not null && distance is > 0 && usablePosition)
        {
            var projection = RouteGeometry.Project(RouteGeometry.FromGeoJson(route),
                new(position!.Latitude, position.Longitude));
            var travelled = Math.Clamp(projection.DistanceAlongRouteMeters, 0, distance.Value);
            remaining = Math.Max(0, distance.Value - travelled);
            progress = decimal.Round(Math.Clamp(travelled / distance.Value * 100, 0, 100), 1);
            offRoute = projection.DistanceFromRouteMeters > progressPolicy.OffRouteThresholdMeters;
            if (position.Speed > 0.5m)
                eta = now.AddSeconds((double)(remaining.Value / (position.Speed * 1000 / 3600)));
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
        return new(trip.Id, trip.TripNumber, trip.ClientId, clientName,
            trip.TruckId, truck?.PlateNumber, truck?.FleetCode, photo?.Version,
            photo is null || trip.TruckId is null ? null
                : $"/api/trucks/{trip.TruckId}/photo/thumbnail?v={photo.Version}",
            trip.DriverId, driver?.FullName, trip.Status.ToString(), phase,
            milestone, stop?.Name, progress, remaining, eta,
            position?.RecordedAt, health, position?.IsOnline, offRoute,
            attention, priority, waiting ? trip.UpdatedAt : null);
    }

    private static (string Phase, string Milestone, TripStop? Stop, bool Waiting) Phase(Trip trip)
    {
        var first = trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault();
        var last = trip.Stops.OrderBy(x => x.Sequence).LastOrDefault();
        return trip.Status switch
        {
            TripStatus.Assigned => ("AwaitingDeparture", "DriverDeparture", first, true),
            TripStatus.EnRouteToPickup => ("ToPickup", "Pickup", first, false),
            TripStatus.AtPickup => ("AwaitingLoading", "LoadingConfirmation", first, true),
            TripStatus.Started or TripStatus.InTransit => ("ToDelivery", "Delivery", last, false),
            TripStatus.AtDelivery => ("AwaitingDeliveryConfirmation", "DeliveryConfirmation", last, true),
            TripStatus.Delivered => ("AwaitingCompletion", "Completion", last, true),
            _ => (trip.Status.ToString(), trip.Status.ToString(), null, false)
        };
    }
}
