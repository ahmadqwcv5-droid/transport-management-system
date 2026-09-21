using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Tracking;
using System.Text.Json;

namespace TransportManagement.Application.Trips;

public sealed class TripService(
    IOperationsStore store,
    ITrackingStore trackingStore,
    ICurrentUser currentUser,
    IClock clock,
    RoutePlanningService routePlanningService,
    DispatchPolicy dispatchPolicy)
{
    public async Task<TripResponse> CreateAsync(TripRequest request, CancellationToken cancellationToken)
    {
        await RequiredActiveClientAsync(request.ClientId, cancellationToken);
        var route = await routePlanningService.PreviewAsync(
            new(request.Stops, request.RouteProfile), cancellationToken);
        var orderedStops = request.Stops.OrderBy(x => x.Sequence).ToArray();
        var trip = new Trip(
            Guid.NewGuid(), currentUser.CompanyId, request.ClientId, orderedStops[0].Name,
            orderedStops[^1].Name, request.CargoDescription, request.PlannedStartAt,
            request.Price, request.Notes, clock.UtcNow);
        trip.ReplaceRoute(CreateStops(trip.Id, orderedStops), CreateRoutePlan(trip.Id, route), clock.UtcNow);
        store.AddTrip(trip);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> UpdateDraftAsync(Guid id, TripRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        await RequiredActiveClientAsync(request.ClientId, cancellationToken);
        var route = await routePlanningService.PreviewAsync(
            new(request.Stops, request.RouteProfile), cancellationToken);
        var orderedStops = request.Stops.OrderBy(x => x.Sequence).ToArray();
        trip.UpdateDraft(request.ClientId, orderedStops[0].Name, orderedStops[^1].Name, request.CargoDescription,
            request.PlannedStartAt, request.Price, request.Notes, clock.UtcNow);
        trip.ReplaceRoute(CreateStops(trip.Id, orderedStops), CreateRoutePlan(trip.Id, route), clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredTripAsync(id, cancellationToken));

    public async Task<IReadOnlyList<TripResponse>> ListAsync(
        TripStatus? status,
        Guid? clientId,
        Guid? truckId,
        Guid? driverId,
        DateTimeOffset? plannedFrom,
        DateTimeOffset? plannedTo,
        CancellationToken cancellationToken) =>
        (await store.ListTripsAsync(status, clientId, truckId, driverId, plannedFrom, plannedTo, cancellationToken))
        .Select(Map).ToArray();

    public async Task<TripResponse> AssignAsync(Guid id, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.RoutePlan is null || trip.Stops.Any(x => !x.HasCoordinates))
            throw new ConflictException("Select geographic stops and calculate a route before assignment.", "ROUTE_PLAN_REQUIRED");
        await RequiredActiveClientAsync(trip.ClientId, cancellationToken);
        var truck = await RequiredTruckAsync(request.TruckId, cancellationToken);
        var driver = await RequiredDriverAsync(request.DriverId, cancellationToken);
        if (!truck.IsActive || truck.Status != TruckStatus.Available)
            throw new ConflictException("The selected truck is not active and available.", "TRUCK_NOT_AVAILABLE");
        if (!driver.IsActive || driver.Status != DriverStatus.Available)
            throw new ConflictException("The selected driver is not active and available.", "DRIVER_NOT_AVAILABLE");
        if (await store.TruckReservedAsync(truck.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected truck is already reserved by an active trip.", "TRUCK_ALREADY_ASSIGNED");
        if (await store.DriverReservedAsync(driver.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected driver is already reserved by an active trip.", "DRIVER_ALREADY_ASSIGNED");
        trip.Assign(truck.Id, driver.Id, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<RepositioningPreviewResponse> PreviewRepositioningAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
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

        var route = await routePlanningService.PreviewAsync(
            new RoutePreviewRequest([
                new(0, "Pickup", "Truck current position", null,
                    position.Latitude, position.Longitude),
                new(1, "Delivery", trip.Stops.OrderBy(x => x.Sequence).First().Name,
                    null, pickup.Latitude, pickup.Longitude)
            ]), cancellationToken);
        var approachCoordinates = RouteGeometry.FromGeoJson(route.Geometry).ToArray();
        approachCoordinates[0] = new(position.Latitude, position.Longitude);
        approachCoordinates[^1] = pickup;
        var approachGeometry = RouteGeometry.ToGeoJson(approachCoordinates);
        var approachDistance = RouteGeometry.DistanceMeters(approachCoordinates);
        var now = clock.UtcNow;
        var plan = new TripRepositioningPlan(
            Guid.NewGuid(), currentUser.CompanyId, trip.Id, truckId,
            position.Latitude, position.Longitude, pickup.Latitude, pickup.Longitude,
            position.Id, position.RecordedAt, approachGeometry, route.GeometryFormat,
            route.GeometryVersion, approachDistance, route.EstimatedDurationSeconds,
            route.ProviderName, route.RouteProfile.ToString(), route.CalculatedAt,
            route.ProviderRouteId, now);
        trip.AddRepositioningPlan(plan, now);
        store.AddRepositioningPlan(plan);
        await store.SaveChangesAsync(cancellationToken);
        return new(trip.Id, false, decimal.Round(directDistance, 1), age, Map(plan));
    }

    public async Task<TripResponse> DispatchToPickupAsync(
        Guid id, DispatchToPickupRequest request, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new DomainRuleException("Dispatch requires an assigned trip.", "INVALID_TRIP_TRANSITION");
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        var pickup = RequiredPickup(trip);
        var directDistance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), pickup
        ]);
        var now = clock.UtcNow;
        if (directDistance <= dispatchPolicy.PickupArrivalRadiusMeters)
        {
            trip.MarkAtPickup(now);
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
                await store.SaveChangesAsync(cancellationToken);
                throw new ConflictException("The truck moved after route proposal; preview again.", "REPOSITIONING_ROUTE_STALE");
            }
            trip.DispatchToPickup(plan, now);
        }
        truck.ChangeStatus(TruckStatus.OnTrip, now);
        driver.ChangeStatus(DriverStatus.OnTrip, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> ArrivePickupAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        if (trip.Status == TripStatus.AtPickup) return Map(trip);
        if (trip.Status is not (TripStatus.Assigned or TripStatus.EnRouteToPickup))
            throw new DomainRuleException("Pickup arrival is not valid for this trip.", "INVALID_TRIP_TRANSITION");
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        EnsureAtPickup(trip, position);
        var now = clock.UtcNow;
        trip.MarkAtPickup(now);
        if (truck.Status != TruckStatus.OnTrip) truck.ChangeStatus(TruckStatus.OnTrip, now);
        if (driver.Status != DriverStatus.OnTrip) driver.ChangeStatus(DriverStatus.OnTrip, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<bool> EvaluateArrivalAsync(
        Guid tripId, TruckPosition position, CancellationToken cancellationToken)
    {
        var trip = await store.GetTripAsync(tripId, cancellationToken);
        if (trip is null || trip.Status != TripStatus.EnRouteToPickup || trip.TruckId != position.TruckId)
            return false;
        var pickup = RequiredPickup(trip);
        var distance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), pickup
        ]);
        if (distance > dispatchPolicy.PickupArrivalRadiusMeters) return false;
        trip.MarkAtPickup(clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<RepositioningProgressResponse> RepositioningProgressAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.TruckId is not Guid truckId)
            throw new ConflictException("The trip has no assigned truck.", "TRIP_TRUCK_REQUIRED");
        var plan = trip.RepositioningPlans.OrderByDescending(x => x.CalculatedAt).FirstOrDefault();
        if (plan is null)
            throw new NotFoundException("Repositioning route was not found.", "REPOSITIONING_ROUTE_REQUIRED");
        var position = await trackingStore.LatestRepositioningPositionAsync(
            trip.Id, plan.Id, truckId, cancellationToken);
        if (position is null)
            return new(trip.Id, truckId, trip.Status.ToString(), plan.DistanceMeters,
                0, plan.DistanceMeters, 0, null, null, false);
        var projection = RouteGeometry.Project(
            RouteGeometry.FromGeoJson(plan.Geometry),
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
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        var position = await RequiredTrustedPositionAsync(truck.Id, cancellationToken);
        EnsureAtPickup(trip, position);
        var now = clock.UtcNow;
        trip.Start(now);
        if (truck.Status != TruckStatus.OnTrip) truck.ChangeStatus(TruckStatus.OnTrip, now);
        if (driver.Status != DriverStatus.OnTrip) driver.ChangeStatus(DriverStatus.OnTrip, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public Task<TripResponse> MarkInTransitAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.MarkInTransit(now), cancellationToken);

    public Task<TripResponse> DeliverAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.Deliver(now), cancellationToken);

    public async Task<TripResponse> CompleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        var now = clock.UtcNow;
        trip.Complete(now);
        truck.ChangeStatus(TruckStatus.Available, now);
        driver.ChangeStatus(DriverStatus.Available, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> CancelAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        var releaseResources = trip.Status is TripStatus.EnRouteToPickup or TripStatus.AtPickup
            or TripStatus.Started or TripStatus.InTransit;
        Truck? truck = null;
        Driver? driver = null;
        if (releaseResources)
        {
            (_, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        }
        var now = clock.UtcNow;
        trip.Cancel(now);
        truck?.ChangeStatus(TruckStatus.Available, now);
        driver?.ChangeStatus(DriverStatus.Available, now);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    private async Task<TripResponse> TransitionAsync(Guid id, Action<Trip, DateTimeOffset> transition, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        transition(trip, clock.UtcNow);
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    private async Task<(Trip Trip, Truck Truck, Driver Driver)> RequiredAssignedResourcesAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.TruckId is null || trip.DriverId is null)
            throw new DomainRuleException("The trip has no assigned truck and driver.");
        return (trip,
            await RequiredTruckAsync(trip.TruckId.Value, cancellationToken),
            await RequiredDriverAsync(trip.DriverId.Value, cancellationToken));
    }

    private async Task<Client> RequiredActiveClientAsync(Guid id, CancellationToken cancellationToken)
    {
        var client = await store.GetClientAsync(id, cancellationToken)
            ?? throw new NotFoundException("Client was not found in the current company.", "CLIENT_NOT_FOUND");
        if (!client.IsActive)
            throw new ConflictException("The selected client is inactive.", "CLIENT_INACTIVE");
        return client;
    }

    private async Task<Trip> RequiredTripAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetTripAsync(id, cancellationToken)
        ?? throw new NotFoundException("Trip was not found.", "TRIP_NOT_FOUND");

    private async Task<Truck> RequiredTruckAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetTruckAsync(id, cancellationToken)
        ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");

    private async Task<Driver> RequiredDriverAsync(Guid id, CancellationToken cancellationToken) =>
        await store.GetDriverAsync(id, cancellationToken)
        ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");

    private static TripResponse Map(Trip trip) => new(
        trip.Id, trip.ClientId, trip.TruckId, trip.DriverId, trip.Origin, trip.Destination,
        trip.CargoDescription, trip.PlannedStartAt, trip.ActualStartAt, trip.ArrivedPickupAt, trip.DeliveredAt,
        trip.CompletedAt, trip.Price, trip.Notes, trip.Status, AllowedActions(trip.Status),
        trip.Stops.OrderBy(x => x.Sequence).Select(x => new TripStopResponse(
            x.Id, x.Sequence, x.Type, x.Name, x.Address, x.Latitude, x.Longitude,
            x.PlannedArrivalAt, x.PlannedServiceDurationMinutes)).ToArray(),
        trip.RoutePlan is null ? null : new TripRoutePlanResponse(
            trip.RoutePlan.Id, trip.RoutePlan.Geometry, trip.RoutePlan.GeometryFormat,
            trip.RoutePlan.GeometryVersion, trip.RoutePlan.DistanceMeters,
            trip.RoutePlan.EstimatedDurationSeconds, trip.RoutePlan.ProviderName,
            trip.RoutePlan.RouteProfile, trip.RoutePlan.CalculatedAt,
            trip.RoutePlan.StopsFingerprint, trip.RoutePlan.ProviderRouteId,
            trip.RoutePlan.Warnings),
        trip.RepositioningPlans.OrderByDescending(x => x.CalculatedAt).Select(Map).FirstOrDefault(),
        trip.RoutePlan is null || trip.Stops.Any(x => !x.HasCoordinates),
        trip.CreatedAt, trip.UpdatedAt);

    private TripStop[] CreateStops(Guid tripId, IReadOnlyList<RouteStopRequest> stops) =>
        stops.Select(stop => new TripStop(
            Guid.NewGuid(), currentUser.CompanyId, tripId, stop.Sequence,
            Enum.Parse<TripStopType>(stop.Type, true), stop.Name, stop.Address,
            stop.Latitude, stop.Longitude, stop.PlannedArrivalAt,
            stop.PlannedServiceDurationMinutes, clock.UtcNow)).ToArray();

    private TripRoutePlan CreateRoutePlan(Guid tripId, RouteResultResponse route) => new(
        Guid.NewGuid(), currentUser.CompanyId, tripId, route.Geometry,
        route.GeometryFormat, route.GeometryVersion, route.DistanceMeters,
        route.EstimatedDurationSeconds, route.ProviderName, route.RouteProfile.ToString(),
        route.CalculatedAt, route.StopsFingerprint, route.ProviderRouteId,
        route.Warnings.Count == 0 ? null : JsonSerializer.Serialize(route.Warnings), clock.UtcNow);

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

    private void EnsureAtPickup(Trip trip, TruckPosition position)
    {
        var pickup = RequiredPickup(trip);
        var distance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), pickup
        ]);
        if (distance > dispatchPolicy.PickupArrivalRadiusMeters)
            throw new ConflictException("The truck has not reached the pickup.", "TRUCK_NOT_AT_PICKUP");
    }

    private static TripRepositioningPlanResponse Map(TripRepositioningPlan plan) => new(
        plan.Id, plan.TripId, plan.TruckId, plan.OriginLatitude, plan.OriginLongitude,
        plan.DestinationLatitude, plan.DestinationLongitude, plan.SourceTruckPositionId,
        plan.SourcePositionAt, plan.Geometry, plan.GeometryFormat, plan.GeometryVersion,
        plan.DistanceMeters, plan.EstimatedDurationSeconds, plan.ProviderName,
        plan.RouteProfile, plan.CalculatedAt, plan.ProviderRouteId, plan.Status,
        plan.DispatchedAt, plan.ArrivedPickupAt);

    private static string[] AllowedActions(TripStatus status) => status switch
    {
        TripStatus.Draft => ["edit", "assign", "cancel"],
        TripStatus.Assigned => ["preview-repositioning", "dispatch-to-pickup", "cancel"],
        TripStatus.EnRouteToPickup => ["arrive-pickup", "cancel"],
        TripStatus.AtPickup => ["start", "cancel"],
        TripStatus.Started => ["mark-in-transit", "cancel"],
        TripStatus.InTransit => ["deliver", "cancel"],
        TripStatus.Delivered => ["complete"],
        _ => []
    };
}
