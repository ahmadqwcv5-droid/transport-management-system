using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;
using System.Text.Json;

namespace TransportManagement.Application.Trips;

public sealed class TripRoutingService(
    ITripStore tripStore,
    ITrackingStore trackingStore,
    ICurrentUser currentUser,
    IClock clock,
    RoutePlanningService routePlanningService,
    DispatchPolicy dispatchPolicy,
    TripEntityResolver resolver,
    TripEventWriter events)
{
    public async Task<TripResponse> CalculateAsync(
        Guid id, CalculateTripRouteRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Draft || trip.Stops.Count != 2
            || trip.Stops.Any(x => !x.HasCoordinates))
            throw new ConflictException("Complete pickup and delivery before route calculation.", "TRIP_NOT_READY_FOR_ROUTE");
        var stopRequests = trip.Stops.OrderBy(x => x.Sequence).Select(x => new RouteStopRequest(
            x.Sequence, x.Type.ToString(), x.Name, x.Address, x.Latitude!.Value,
            x.Longitude!.Value, x.PlannedArrivalAt, x.PlannedServiceDurationMinutes)).ToArray();
        var route = await routePlanningService.PreviewAsync(
            new(stopRequests, request.RouteProfile), cancellationToken);
        var routePlan = new TripRoutePlan(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, route.Geometry, route.GeometryFormat, route.GeometryVersion,
            route.DistanceMeters, route.EstimatedDurationSeconds, route.ProviderName,
            route.RouteProfile.ToString(), route.CalculatedAt, route.StopsFingerprint,
            route.ProviderRouteId, route.Warnings.Count == 0 ? null
                : JsonSerializer.Serialize(route.Warnings), clock.UtcNow);
        trip.ReplaceRoute(trip.Stops.ToArray(), routePlan, clock.UtcNow);
        tripStore.AddTripRoutePlan(routePlan);
        events.Append(trip, "RouteCalculated", new
            { route.ProviderName, route.StopsFingerprint });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<RepositioningPreviewResponse> PreviewRepositioningAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new DomainRuleException("Repositioning preview requires an assigned trip.", "INVALID_TRIP_TRANSITION");
        if (trip.TruckId is not Guid truckId)
            throw new ConflictException("The trip has no assigned truck.", "TRIP_TRUCK_REQUIRED");
        var position = await RequiredTrustedPositionAsync(truckId, cancellationToken);
        var pickup = RequiredPickup(trip);
        var directDistance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), pickup
        ]);
        var age = Math.Max(0, (int)(clock.UtcNow - position.RecordedAt).TotalSeconds);
        if (directDistance <= dispatchPolicy.PickupArrivalRadiusMeters)
            return new(trip.Id, true, decimal.Round(directDistance, 1), age, null);
        var route = await routePlanningService.PreviewAsync(new RoutePreviewRequest([
            new(0, "Pickup", "Truck current position", null,
                position.Latitude, position.Longitude),
            new(1, "Delivery", trip.Stops.OrderBy(x => x.Sequence).First().Name,
                null, pickup.Latitude, pickup.Longitude)
        ]), cancellationToken);
        var coordinates = RouteGeometry.FromGeoJson(route.Geometry).ToArray();
        coordinates[0] = new(position.Latitude, position.Longitude);
        coordinates[^1] = pickup;
        var now = clock.UtcNow;
        var plan = new TripRepositioningPlan(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, truckId, position.Latitude, position.Longitude,
            pickup.Latitude, pickup.Longitude, position.Id, position.RecordedAt,
            RouteGeometry.ToGeoJson(coordinates), route.GeometryFormat,
            route.GeometryVersion, RouteGeometry.DistanceMeters(coordinates),
            route.EstimatedDurationSeconds, route.ProviderName,
            route.RouteProfile.ToString(), route.CalculatedAt,
            route.ProviderRouteId, now);
        trip.AddRepositioningPlan(plan, now);
        tripStore.AddRepositioningPlan(plan);
        await tripStore.SaveChangesAsync(cancellationToken);
        return new(trip.Id, false, decimal.Round(directDistance, 1), age,
            TripResponseMapper.Map(plan));
    }

    private async Task<TruckPosition> RequiredTrustedPositionAsync(
        Guid truckId, CancellationToken cancellationToken)
    {
        var position = await trackingStore.LatestPositionAsync(truckId, cancellationToken)
            ?? throw new ConflictException("The truck must report a position before dispatch.", "TRUCK_POSITION_REQUIRED");
        if (clock.UtcNow - position.RecordedAt > dispatchPolicy.MaximumPositionAge)
            throw new ConflictException("The truck position is too old for dispatch.", "TRUCK_POSITION_STALE");
        if (!position.IsOnline)
            throw new ConflictException("The truck must be online for dispatch.", "TRUCK_OFFLINE");
        return position;
    }

    private static GeoCoordinate RequiredPickup(Trip trip)
    {
        var pickup = trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault();
        if (pickup?.Latitude is not decimal latitude || pickup.Longitude is not decimal longitude)
            throw new ConflictException("The trip pickup requires coordinates.", "ROUTE_PLAN_REQUIRED");
        return new(latitude, longitude);
    }
}
