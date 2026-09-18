using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;
using TransportManagement.Application.Routing;
using System.Text.Json;

namespace TransportManagement.Application.Trips;

public sealed class TripService(
    IOperationsStore store,
    ICurrentUser currentUser,
    IClock clock,
    RoutePlanningService routePlanningService)
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

    public async Task<TripResponse> StartAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        if (truck.Status != TruckStatus.Available || driver.Status != DriverStatus.Available)
            throw new ConflictException("Assigned resources are no longer available.", "ASSIGNED_RESOURCES_NOT_AVAILABLE");
        var now = clock.UtcNow;
        trip.Start(now);
        truck.ChangeStatus(TruckStatus.OnTrip, now);
        driver.ChangeStatus(DriverStatus.OnTrip, now);
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
        var releaseResources = trip.Status is TripStatus.Started or TripStatus.InTransit;
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
        trip.CargoDescription, trip.PlannedStartAt, trip.ActualStartAt, trip.DeliveredAt,
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

    private static string[] AllowedActions(TripStatus status) => status switch
    {
        TripStatus.Draft => ["edit", "assign", "cancel"],
        TripStatus.Assigned => ["start", "cancel"],
        TripStatus.Started => ["mark-in-transit", "cancel"],
        TripStatus.InTransit => ["deliver", "cancel"],
        TripStatus.Delivered => ["complete"],
        _ => []
    };
}
