using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Drivers;

public sealed class DriverDepartureService(
    ITripStore trips,
    ITrackingStore tracking,
    IClock clock,
    DispatchPolicy policy,
    TripEntityResolver resolver,
    RoutePlanningService routePlanning,
    TripEventWriter events,
    ResourceEventWriter resourceEvents,
    IDriverIdentityStore identities,
    ICurrentUser currentUser)
{
    public async Task<TripResponse> PrepareAndDepartToPickupAsync(
        Guid driverId, Guid tripId, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await ResolveAssignmentAsync(
            driverId, tripId, cancellationToken);
        if (trip.Status == TripStatus.EnRouteToPickup)
            return TripResponseMapper.Map(trip);
        EnsureAssigned(trip);

        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        var pickup = RequiredPickup(trip);
        var directDistance = Distance(new(position.Latitude, position.Longitude), pickup);
        if (directDistance <= policy.PickupArrivalRadiusMeters)
            return await CompleteAsync(trip, truck, driver, null, false, cancellationToken);

        var reusable = ValidProposedPlan(trip, truck.Id, position, pickup);
        if (reusable is not null)
            return await CompleteAsync(trip, truck, driver, reusable, false, cancellationToken);

        var proposal = new DepartureProposal(
            trip.Id, trip.Version, driver.Id, truck.Id, position.Id,
            position.Latitude, position.Longitude, position.RecordedAt,
            pickup.Latitude, pickup.Longitude);
        RouteResultResponse route;
        try
        {
            route = await routePlanning.PreviewAsync(new RoutePreviewRequest([
                new(0, "Pickup", "Truck current position", null,
                    proposal.OriginLatitude, proposal.OriginLongitude),
                new(1, "Delivery", "Pickup", null,
                    proposal.PickupLatitude, proposal.PickupLongitude)
            ]), cancellationToken);
        }
        catch (ProviderException exception)
        {
            var code = exception.Code == "ROUTING_UNAVAILABLE"
                ? "ROUTING_PROVIDER_UNAVAILABLE" : "ROUTE_CALCULATION_FAILED";
            throw new ProviderException(
                "The route to pickup could not be prepared.", code, exception);
        }

        await trips.ReloadTripAsync(tripId, cancellationToken);
        (trip, truck, driver) = await ResolveAssignmentAsync(
            driverId, tripId, cancellationToken);
        if (trip.Status == TripStatus.EnRouteToPickup)
            return TripResponseMapper.Map(trip);
        EnsureAssigned(trip);
        if (trip.Version != proposal.TripVersion
            || trip.DriverId != proposal.DriverId
            || trip.TruckId != proposal.TruckId)
            throw new ConflictException(
                "The trip assignment changed while the route was prepared.",
                "DRIVER_ASSIGNMENT_CHANGED");

        position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        pickup = RequiredPickup(trip);
        if (Distance(new(proposal.PickupLatitude, proposal.PickupLongitude), pickup) > 1
            || Distance(new(proposal.OriginLatitude, proposal.OriginLongitude),
                new(position.Latitude, position.Longitude))
                > policy.ProposalOriginMovementToleranceMeters)
            throw new ConflictException(
                "The assignment or truck position changed while the route was prepared.",
                "DRIVER_ASSIGNMENT_CHANGED");

        var coordinates = RouteGeometry.FromGeoJson(route.Geometry).ToArray();
        coordinates[0] = new(proposal.OriginLatitude, proposal.OriginLongitude);
        coordinates[^1] = pickup;
        var now = clock.UtcNow;
        var plan = new TripRepositioningPlan(
            Guid.NewGuid(), currentUser.CompanyId, trip.Id, truck.Id,
            proposal.OriginLatitude, proposal.OriginLongitude,
            pickup.Latitude, pickup.Longitude, proposal.PositionId,
            proposal.PositionAt, RouteGeometry.ToGeoJson(coordinates),
            route.GeometryFormat, route.GeometryVersion,
            RouteGeometry.DistanceMeters(coordinates), route.EstimatedDurationSeconds,
            route.ProviderName, route.RouteProfile.ToString(), route.CalculatedAt,
            route.ProviderRouteId, now);
        trip.AddRepositioningPlan(plan, now);
        trips.AddRepositioningPlan(plan);
        return await CompleteAsync(
            trip, truck, driver, plan, true, cancellationToken);
    }

    private async Task<(Trip Trip, Truck Truck, Driver Driver)> ResolveAssignmentAsync(
        Guid driverId, Guid tripId, CancellationToken cancellationToken)
    {
        var resources = await resolver.AssignedResourcesAsync(tripId, cancellationToken);
        if (resources.Trip.DriverId != driverId || resources.Driver.Id != driverId)
            throw new ConflictException(
                "The trip is no longer assigned to the signed-in driver.",
                "DRIVER_ASSIGNMENT_CHANGED");
        return resources;
    }

    private static void EnsureAssigned(Trip trip)
    {
        if (trip.Status != TripStatus.Assigned)
            throw new ConflictException(
                "The trip is not awaiting Driver departure.",
                "TRIP_NOT_ASSIGNED");
    }

    private async Task<TripResponse> CompleteAsync(
        Trip trip, Truck truck, Driver driver, TripRepositioningPlan? plan,
        bool routeGenerated, CancellationToken cancellationToken)
    {
        var now = clock.UtcNow;
        if (plan is null) trip.DispatchForPickupConfirmation(now);
        else trip.DispatchToPickup(plan, now);
        driver.ChangeStatus(DriverStatus.OnTrip, now);

        var conflicts = await identities.GetConflictingSessionsAsync(
            driver.Id, truck.Id, cancellationToken);
        var session = conflicts.FirstOrDefault(x =>
            x.DriverId == driver.Id && x.TruckId == truck.Id);
        foreach (var conflict in conflicts.Where(x => x != session))
            conflict.End("VehicleHandoff", now);
        if (session is null)
        {
            session = new DriverTruckSession(
                Guid.NewGuid(), currentUser.CompanyId, driver.Id, truck.Id, trip.Id, now);
            identities.AddSession(session);
        }
        else session.LinkTrip(trip.Id, now);

        events.Append(trip, "DriverDepartedToPickup", new
        {
            approachRouteId = plan?.Id,
            routeGenerated,
            routeReused = plan is not null && !routeGenerated
        });
        resourceEvents.Truck(truck.Id, "TruckDispatchedToPickup",
            new { tripId = trip.Id, trip.TripNumber, source = "Driver" });
        await trips.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    private TripRepositioningPlan? ValidProposedPlan(
        Trip trip, Guid truckId, TruckPosition position, GeoCoordinate pickup)
    {
        var plan = trip.CurrentRepositioningPlan;
        if (plan is null || plan.Status != RepositioningPlanStatus.Proposed
            || plan.CompanyId != currentUser.CompanyId
            || plan.TripId != trip.Id || plan.TruckId != truckId
            || plan.RouteProfile != RouteProfile.Driving.ToString()
            || clock.UtcNow - plan.SourcePositionAt > policy.MaximumPositionAge
            || Distance(new(plan.DestinationLatitude, plan.DestinationLongitude), pickup) > 1
            || Distance(new(plan.OriginLatitude, plan.OriginLongitude),
                new(position.Latitude, position.Longitude))
                > policy.ProposalOriginMovementToleranceMeters)
            return null;
        return plan;
    }

    private async Task<TruckPosition> RequiredTrustedPositionAsync(
        Guid truckId, CancellationToken cancellationToken)
    {
        var position = await tracking.LatestPositionAsync(truckId, cancellationToken)
            ?? throw new ConflictException(
                "The truck must report a position before departure.",
                "TRUCK_POSITION_REQUIRED");
        if (!position.IsOnline)
            throw new ConflictException(
                "The truck tracking is offline.", "TRUCK_OFFLINE");
        if (clock.UtcNow - position.RecordedAt > policy.MaximumPositionAge)
            throw new ConflictException(
                "The truck position is too old for departure.",
                "TRUCK_POSITION_STALE");
        return position;
    }

    private static GeoCoordinate RequiredPickup(Trip trip)
    {
        var pickup = trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault();
        if (pickup?.Latitude is not decimal latitude
            || pickup.Longitude is not decimal longitude)
            throw new ConflictException(
                "The pickup requires coordinates.",
                "PICKUP_COORDINATES_REQUIRED");
        return new(latitude, longitude);
    }

    private static decimal Distance(GeoCoordinate from, GeoCoordinate to) =>
        RouteGeometry.DistanceMeters([from, to]);

    private sealed record DepartureProposal(
        Guid TripId, long TripVersion, Guid DriverId, Guid TruckId,
        Guid PositionId, decimal OriginLatitude, decimal OriginLongitude,
        DateTimeOffset PositionAt, decimal PickupLatitude,
        decimal PickupLongitude);
}
