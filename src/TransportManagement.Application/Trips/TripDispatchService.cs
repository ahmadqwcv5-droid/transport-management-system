using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed class TripDispatchService(
    ITripStore tripStore,
    ITrackingStore trackingStore,
    IClock clock,
    DispatchPolicy dispatchPolicy,
    TripEntityResolver resolver,
    TripEventWriter events,
    ResourceEventWriter resourceEvents)
{
    public async Task<TripResponse> DispatchToPickupAsync(
        Guid id, DispatchToPickupRequest request, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await resolver.AssignedResourcesAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new DomainRuleException("Dispatch requires an assigned trip.", "INVALID_TRIP_TRANSITION");
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        var pickup = RequiredPickup(trip);
        var distance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), pickup
        ]);
        var now = clock.UtcNow;
        if (distance <= dispatchPolicy.PickupArrivalRadiusMeters)
        {
            trip.DispatchForPickupConfirmation(now);
        }
        else
        {
            var plan = trip.CurrentRepositioningPlan;
            if (plan is null || request.RepositioningPlanId != plan.Id)
                throw new ConflictException("A valid repositioning route is required.", "REPOSITIONING_ROUTE_REQUIRED");
            var moved = RouteGeometry.DistanceMeters([
                new(plan.OriginLatitude, plan.OriginLongitude),
                new(position.Latitude, position.Longitude)
            ]);
            if (moved > dispatchPolicy.ProposalOriginMovementToleranceMeters)
            {
                plan.Expire(now);
                await tripStore.SaveChangesAsync(cancellationToken);
                throw new ConflictException("The truck moved after route proposal; preview again.", "REPOSITIONING_ROUTE_STALE");
            }
            trip.DispatchToPickup(plan, now);
        }
        driver.ChangeStatus(DriverStatus.OnTrip, now);
        events.Append(trip, "DispatchedToPickup");
        resourceEvents.Truck(truck.Id, "TruckDispatchedToPickup",
            new { tripId = trip.Id, trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> ArrivePickupAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await resolver.AssignedResourcesAsync(id, cancellationToken);
        if (trip.Status == TripStatus.AtPickup) return TripResponseMapper.Map(trip);
        if (trip.Status is not (TripStatus.Assigned or TripStatus.EnRouteToPickup))
            throw new DomainRuleException("Pickup arrival is not valid for this trip.", "INVALID_TRIP_TRANSITION");
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        EnsureAtPickup(trip, position);
        var now = clock.UtcNow;
        trip.MarkAtPickup(now);
        if (driver.Status != DriverStatus.OnTrip) driver.ChangeStatus(DriverStatus.OnTrip, now);
        events.Append(trip, "ArrivedAtPickup");
        resourceEvents.Truck(truck.Id, "TruckArrivedAtPickup",
            new { tripId = trip.Id, trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<RepositioningProgressResponse> ProgressAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.TruckId is not Guid truckId)
            throw new ConflictException("The trip has no assigned truck.", "TRIP_TRUCK_REQUIRED");
        var plan = trip.RepositioningPlans.OrderByDescending(x => x.CalculatedAt).FirstOrDefault()
            ?? throw new NotFoundException("Repositioning route was not found.", "REPOSITIONING_ROUTE_REQUIRED");
        var position = await trackingStore.LatestRepositioningPositionAsync(
            trip.Id, plan.Id, truckId, cancellationToken);
        if (position is null)
            return new(trip.Id, truckId, trip.Status.ToString(), plan.DistanceMeters,
                0, plan.DistanceMeters, 0, null, null, false);
        var projection = RouteGeometry.Project(RouteGeometry.FromGeoJson(plan.Geometry),
            new(position.Latitude, position.Longitude));
        var travelled = Math.Clamp(projection.DistanceAlongRouteMeters, 0, plan.DistanceMeters);
        var remaining = Math.Max(0, plan.DistanceMeters - travelled);
        var percent = plan.DistanceMeters <= 0 ? 0
            : decimal.Round(Math.Clamp(travelled / plan.DistanceMeters * 100, 0, 100), 1);
        DateTimeOffset? eta = position.Speed > 0.5m
            ? clock.UtcNow.AddSeconds((double)(remaining / (position.Speed * 1000 / 3600)))
            : remaining <= dispatchPolicy.PickupArrivalRadiusMeters ? position.RecordedAt : null;
        return new(trip.Id, truckId, trip.Status.ToString(), plan.DistanceMeters,
            travelled, remaining, percent, eta, position.RecordedAt, false);
    }

    public async Task<TripResponse> StartAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await resolver.AssignedResourcesAsync(id, cancellationToken);
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        EnsureAtPickup(trip, position);
        var now = clock.UtcNow;
        trip.Start(now);
        if (driver.Status != DriverStatus.OnTrip) driver.ChangeStatus(DriverStatus.OnTrip, now);
        events.Append(trip, "TripStarted");
        resourceEvents.Truck(truck.Id, "TruckTripStarted",
            new { tripId = trip.Id, trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
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

    private void EnsureAtPickup(Trip trip, TruckPosition position)
    {
        var distance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), RequiredPickup(trip)
        ]);
        if (distance > dispatchPolicy.PickupArrivalRadiusMeters)
            throw new ConflictException("The truck has not reached the pickup.", "TRUCK_NOT_AT_PICKUP");
    }

    private static GeoCoordinate RequiredPickup(Trip trip)
    {
        var pickup = trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault();
        if (pickup?.Latitude is not decimal latitude || pickup.Longitude is not decimal longitude)
            throw new ConflictException("The trip pickup requires coordinates.", "ROUTE_PLAN_REQUIRED");
        return new(latitude, longitude);
    }
}
