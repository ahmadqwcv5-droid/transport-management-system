using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Routing;

public sealed record RouteProgressPolicy(decimal OffRouteThresholdMeters, decimal ArrivalThresholdMeters);

public sealed class RouteProgressService(
    IOperationsStore operationsStore,
    ITrackingStore trackingStore,
    IClock clock,
    RouteProgressPolicy policy)
{
    public async Task<RouteProgressResponse> GetAsync(Guid tripId, CancellationToken cancellationToken)
    {
        var trip = await operationsStore.GetTripAsync(tripId, cancellationToken)
            ?? throw new NotFoundException("Trip was not found.", "TRIP_NOT_FOUND");
        if (trip.RoutePlan is null)
            return Unavailable(trip, "Route unavailable");
        if (trip.TruckId is null)
            return Unavailable(trip, "Awaiting start");
        var position = await trackingStore.LatestPositionAsync(trip.TruckId.Value, cancellationToken);
        if (position is null)
            return Unavailable(trip, "Tracking unavailable");

        var geometry = RouteGeometry.FromGeoJson(trip.RoutePlan.Geometry);
        var projection = RouteGeometry.Project(geometry, new(position.Latitude, position.Longitude));
        var planned = trip.RoutePlan.DistanceMeters;
        var travelled = Math.Clamp(projection.DistanceAlongRouteMeters, 0, planned);
        var remaining = Math.Max(0, planned - travelled);
        var percent = planned <= 0 ? 0 : decimal.Round(Math.Clamp(travelled / planned * 100, 0, 100), 1);
        var offRoute = projection.DistanceFromRouteMeters > policy.OffRouteThresholdMeters;
        var atDelivery = remaining <= policy.ArrivalThresholdMeters;
        DateTimeOffset? eta = position.Speed > 0.5m
            ? clock.UtcNow.AddSeconds((double)(remaining / (position.Speed * 1000 / 3600)))
            : atDelivery ? position.RecordedAt : null;
        var phase = Phase(trip, percent, atDelivery, offRoute);
        return new(trip.Id, trip.TruckId, planned, travelled, remaining, percent, eta,
            decimal.Round(projection.DistanceFromRouteMeters, 1), offRoute,
            projection.SegmentIndex, phase, position.RecordedAt);
    }

    private static RouteProgressResponse Unavailable(Trip trip, string phase) =>
        new(trip.Id, trip.TruckId, trip.RoutePlan?.DistanceMeters ?? 0,
            null, null, null, null, null, null, null, phase, null);

    private static string Phase(Trip trip, decimal percent, bool atDelivery, bool offRoute)
    {
        if (trip.Status == TripStatus.Completed) return "Completed";
        if (offRoute) return "Off route";
        if (atDelivery) return "At delivery";
        if (trip.Status is TripStatus.Draft or TripStatus.Assigned) return "Awaiting start";
        if (percent <= 1) return "At pickup";
        if (percent >= 90) return "Approaching delivery";
        return "In transit";
    }
}
