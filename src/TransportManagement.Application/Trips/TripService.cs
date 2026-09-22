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
        var now = clock.UtcNow;
        var number = await store.AllocateTripNumberAsync(
            currentUser.CompanyId, now.UtcDateTime.Year, cancellationToken);
        var trip = new Trip(
            Guid.NewGuid(), currentUser.CompanyId, number, request.ClientId,
            request.CargoDescription, request.PlannedStartAt,
            request.Price, request.Notes, clock.UtcNow);
        if (request.Stops is { Count: > 0 })
            trip.ReplaceStops(CreateStops(trip.Id, request.Stops), trip.Version, now);
        store.AddTrip(trip);
        AppendEvent(trip, "TripCreated", new { trip.TripNumber });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> UpdateDraftAsync(Guid id, TripRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        await RequiredActiveClientAsync(request.ClientId, cancellationToken);
        var changed = trip.UpdateDraft(request.ClientId, request.CargoDescription,
            request.PlannedStartAt, request.Price, request.Notes,
            request.ExpectedVersion ?? trip.Version, clock.UtcNow);
        if (!changed) return Map(trip);
        AppendEvent(trip, "DraftUpdated");
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> UpdateStopsAsync(
        Guid id, UpdateTripStopsRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        var stops = CreateStops(trip.Id, request.Stops);
        var replacesStopEntities = trip.Stops.Count != stops.Length
            || !trip.Stops.OrderBy(x => x.Sequence).Select(x => (x.Sequence, x.Type))
                .SequenceEqual(stops.OrderBy(x => x.Sequence).Select(x => (x.Sequence, x.Type)));
        var invalidateRoute = RouteInputsChanged(trip, request.Stops);
        var previousRouteId = trip.RoutePlan?.Id;
        var replacement = trip.ReplaceStops(
            stops, request.ExpectedVersion, clock.UtcNow, invalidateRoute);
        if (!replacement.StopsChanged) return Map(trip);
        if (replacesStopEntities)
            store.AddTripStops(stops);
        AppendEvent(trip, "StopsUpdated");
        if (replacement.RouteInvalidated)
            AppendEvent(trip, "RouteInvalidated", new { previousRouteId });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> CalculateRouteAsync(
        Guid id, CalculateTripRouteRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Draft || trip.Stops.Count != 2 || trip.Stops.Any(x => !x.HasCoordinates))
            throw new ConflictException("Complete pickup and delivery before route calculation.", "TRIP_NOT_READY_FOR_ROUTE");
        var stopRequests = trip.Stops.OrderBy(x => x.Sequence).Select(x => new RouteStopRequest(
            x.Sequence, x.Type.ToString(), x.Name, x.Address, x.Latitude!.Value,
            x.Longitude!.Value, x.PlannedArrivalAt, x.PlannedServiceDurationMinutes)).ToArray();
        var route = await routePlanningService.PreviewAsync(
            new(stopRequests, request.RouteProfile), cancellationToken);
        var routePlan = CreateRoutePlan(trip.Id, route);
        trip.ReplaceRoute(trip.Stops.ToArray(), routePlan, clock.UtcNow);
        store.AddTripRoutePlan(routePlan);
        AppendEvent(trip, "RouteCalculated", new { route.ProviderName, route.StopsFingerprint });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> GetAsync(Guid id, CancellationToken cancellationToken) =>
        Map(await RequiredTripAsync(id, cancellationToken));

    public async Task<TripPageResponse> QueryAsync(
        TripListQuery query, CancellationToken cancellationToken)
    {
        if (query.Page < 1 || query.PageSize is < 1 or > 100)
            throw new DomainRuleException("Page must be positive and page size must be between 1 and 100.", "INVALID_PAGINATION");
        if (!new[] { "plannedstart", "tripnumber", "created", "status" }.Contains(query.Sort.ToLowerInvariant())
            || !new[] { "asc", "desc" }.Contains(query.Direction.ToLowerInvariant()))
            throw new DomainRuleException("Sort is not supported.", "INVALID_SORT");
        if (!string.IsNullOrWhiteSpace(query.OperationalGroup)
            && !new[] { "active", "planned", "completed", "cancelled", "archived" }
                .Contains(query.OperationalGroup.ToLowerInvariant()))
            throw new DomainRuleException("Operational group is not supported.", "INVALID_TRIP_FILTER");
        var (items, total) = await store.QueryTripsAsync(query, cancellationToken);
        return new(items.Select(Map).ToArray(), total, query.Page, query.PageSize,
            (int)Math.Ceiling(total / (double)query.PageSize));
    }

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

    public async Task<TripTimelineResponse> TimelineAsync(
        Guid id, int page, int pageSize, CancellationToken cancellationToken)
    {
        _ = await RequiredTripAsync(id, cancellationToken);
        if (page < 1 || pageSize is < 1 or > 100)
            throw new DomainRuleException("Timeline pagination is invalid.", "INVALID_PAGINATION");
        var (events, total) = await store.ListTripEventsAsync(id, page, pageSize, cancellationToken);
        var items = new List<TripEventResponse>(events.Count);
        foreach (var item in events)
        {
            var actor = item.ActorUserId.HasValue
                ? await store.UserDisplayNameAsync(item.ActorUserId.Value, cancellationToken)
                : null;
            items.Add(new(item.Id, item.EventType, item.OccurredAt, item.ActorUserId,
                actor ?? "System", item.Source, item.Metadata));
        }
        return new(items, total, page, pageSize, (int)Math.Ceiling(total / (double)pageSize));
    }

    public async Task<AssignmentOptionsResponse> AssignmentOptionsAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        var readiness = Readiness(trip);
        var canChoose = trip.Status == TripStatus.Draft
            ? readiness.CanAssign
            : trip.Status == TripStatus.Assigned;
        var trucks = await store.ListTrucksAsync(null, null, null, cancellationToken);
        var drivers = await store.ListDriversAsync(null, null, null, cancellationToken);
        var truckReservations = (await store.TruckReservationsAsync(trip.Id, cancellationToken))
            .GroupBy(x => x.ResourceId).ToDictionary(x => x.Key, x => x.First());
        var driverReservations = (await store.DriverReservationsAsync(trip.Id, cancellationToken))
            .GroupBy(x => x.ResourceId).ToDictionary(x => x.Key, x => x.First());

        return new(trip.Id, trip.TruckId, trip.DriverId, canChoose,
            trucks.Select(truck => TruckOption(truck, canChoose,
                truckReservations.GetValueOrDefault(truck.Id))).ToArray(),
            drivers.Select(driver => DriverOption(driver, canChoose,
                driverReservations.GetValueOrDefault(driver.Id))).ToArray());
    }

    public async Task<TripResponse> AssignAsync(Guid id, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (!Readiness(trip).CanAssign)
            throw new ConflictException("Complete the Draft and calculate its current route before assignment.", "TRIP_NOT_READY_FOR_ASSIGNMENT");
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
        AppendEvent(trip, "Assigned", new { truckId = truck.Id, driverId = driver.Id });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> ReassignAsync(Guid id, AssignTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new ConflictException("Only a trip awaiting dispatch can be reassigned.", "TRIP_REASSIGN_NOT_ALLOWED");
        var oldTruckId = trip.TruckId;
        var oldDriverId = trip.DriverId;
        var truck = await RequiredTruckAsync(request.TruckId, cancellationToken);
        var driver = await RequiredDriverAsync(request.DriverId, cancellationToken);
        if (!truck.IsActive || truck.Status != TruckStatus.Available)
            throw new ConflictException("The selected truck is unavailable.", "TRUCK_NOT_AVAILABLE");
        if (!driver.IsActive || driver.Status != DriverStatus.Available)
            throw new ConflictException("The selected driver is unavailable.", "DRIVER_NOT_AVAILABLE");
        if (await store.TruckReservedAsync(truck.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected truck is already reserved.", "TRUCK_ALREADY_ASSIGNED");
        if (await store.DriverReservedAsync(driver.Id, trip.Id, cancellationToken))
            throw new ConflictException("The selected driver is already reserved.", "DRIVER_ALREADY_ASSIGNED");
        trip.Reassign(truck.Id, driver.Id, clock.UtcNow);
        AppendEvent(trip, "Reassigned", new { oldTruckId, oldDriverId, newTruckId = truck.Id, newDriverId = driver.Id });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> UnassignAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Assigned)
            throw new ConflictException("Only a trip awaiting dispatch can be unassigned.", "TRIP_UNASSIGN_NOT_ALLOWED");
        var oldTruckId = trip.TruckId;
        var oldDriverId = trip.DriverId;
        trip.Unassign(clock.UtcNow);
        AppendEvent(trip, "Unassigned", new { oldTruckId, oldDriverId });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task DeleteDraftAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Draft || trip.RepositioningPlans.Count != 0
            || trip.ActualStartAt.HasValue || trip.ArrivedPickupAt.HasValue
            || await trackingStore.HasTripHistoryAsync(id, cancellationToken))
            throw new ConflictException("Only a never-executed Draft may be permanently deleted.", "TRIP_DELETE_NOT_ALLOWED");
        store.RemoveTrip(trip);
        await store.SaveChangesAsync(cancellationToken);
    }

    public async Task<TripResponse> DuplicateAsync(Guid id, CancellationToken cancellationToken)
    {
        var source = await RequiredTripAsync(id, cancellationToken);
        await RequiredActiveClientAsync(source.ClientId, cancellationToken);
        var now = clock.UtcNow;
        var number = await store.AllocateTripNumberAsync(currentUser.CompanyId,
            now.UtcDateTime.Year, cancellationToken);
        var copy = new Trip(Guid.NewGuid(), currentUser.CompanyId, number,
            source.ClientId, source.CargoDescription, source.PlannedStartAt,
            source.Price, source.Notes, now);
        if (source.Stops.Count > 0)
        {
            var stops = source.Stops.OrderBy(x => x.Sequence).Select(x => new TripStop(
                Guid.NewGuid(), currentUser.CompanyId, copy.Id, x.Sequence, x.Type,
                x.Name, x.Address, x.Latitude, x.Longitude, x.PlannedArrivalAt,
                x.PlannedServiceDurationMinutes, now)).ToArray();
            copy.ReplaceStops(stops, copy.Version, now);
        }
        store.AddTrip(copy);
        AppendEvent(copy, "TripCreated", new { duplicatedFromTripId = source.Id, source.TripNumber });
        await store.SaveChangesAsync(cancellationToken);
        return Map(copy);
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
        AppendEvent(trip, trip.Status == TripStatus.AtPickup ? "ArrivedAtPickup" : "DispatchedToPickup");
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
        AppendEvent(trip, "ArrivedAtPickup");
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
        AppendEvent(trip, "ArrivedAtPickup", source: "System");
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
        AppendEvent(trip, "TripStarted");
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public Task<TripResponse> MarkInTransitAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.MarkInTransit(now), "MarkedInTransit", cancellationToken);

    public Task<TripResponse> DeliverAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.Deliver(now), "Delivered", cancellationToken);

    public async Task<TripResponse> CompleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await RequiredAssignedResourcesAsync(id, cancellationToken);
        var now = clock.UtcNow;
        trip.Complete(now);
        truck.ChangeStatus(TruckStatus.Available, now);
        driver.ChangeStatus(DriverStatus.Available, now);
        AppendEvent(trip, "Completed");
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> CancelAsync(Guid id, CancelTripRequest request, CancellationToken cancellationToken)
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
        var previousStatus = trip.Status;
        trip.Cancel(request.Reason, currentUser.UserId, now);
        truck?.ChangeStatus(TruckStatus.Available, now);
        driver?.ChangeStatus(DriverStatus.Available, now);
        AppendEvent(trip, "Cancelled", new { previousStatus, reason = trip.CancellationReason });
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> ArchiveAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        trip.Archive(currentUser.UserId, clock.UtcNow);
        AppendEvent(trip, "Archived");
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    public async Task<TripResponse> UnarchiveAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        trip.Unarchive(clock.UtcNow);
        AppendEvent(trip, "Unarchived");
        await store.SaveChangesAsync(cancellationToken);
        return Map(trip);
    }

    private async Task<TripResponse> TransitionAsync(Guid id,
        Action<Trip, DateTimeOffset> transition, string eventType,
        CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(id, cancellationToken);
        transition(trip, clock.UtcNow);
        AppendEvent(trip, eventType);
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
        trip.Id, trip.TripNumber, trip.ClientId, trip.TruckId, trip.DriverId, trip.Origin, trip.Destination,
        trip.CargoDescription, trip.PlannedStartAt, trip.ActualStartAt, trip.ArrivedPickupAt, trip.DeliveredAt,
        trip.CompletedAt, trip.Price, trip.Notes, trip.Status, trip.IsArchived,
        trip.ArchivedAt, trip.CancellationReason, trip.CancelledAt, trip.Version,
        Readiness(trip), AllowedActions(trip),
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

    private static TripReadinessResponse Readiness(Trip trip)
    {
        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(trip.CargoDescription)) missing.Add("CARGO_REQUIRED");
        if (trip.PlannedStartAt is null) missing.Add("PLANNED_START_REQUIRED");
        if (trip.Price is null) missing.Add("PRICE_REQUIRED");
        var ordered = trip.Stops.OrderBy(x => x.Sequence).ToArray();
        var validStops = ordered.Length == 2 && ordered[0].Type == TripStopType.Pickup
            && ordered[^1].Type == TripStopType.Delivery && ordered.All(x => x.HasCoordinates);
        if (!validStops) missing.Add("STOPS_REQUIRED");
        var routeCurrent = false;
        if (validStops && trip.RoutePlan is not null
            && Enum.TryParse<RouteProfile>(trip.RoutePlan.RouteProfile, out var profile))
        {
            var requests = ordered.Select(x => new RouteStopRequest(x.Sequence,
                x.Type.ToString(), x.Name, x.Address, x.Latitude!.Value,
                x.Longitude!.Value, x.PlannedArrivalAt,
                x.PlannedServiceDurationMinutes)).ToArray();
            routeCurrent = RoutePlanningService.Fingerprint(requests, profile)
                == trip.RoutePlan.StopsFingerprint;
        }
        if (!routeCurrent) missing.Add("CURRENT_ROUTE_REQUIRED");
        return new(validStops && trip.Status == TripStatus.Draft,
            trip.Status == TripStatus.Draft && missing.Count == 0,
            trip.Status == TripStatus.Assigned && routeCurrent, missing);
    }

    private void AppendEvent(Trip trip, string eventType, object? metadata = null,
        string source = "User")
    {
        var now = clock.UtcNow;
        store.AddTripEvent(new TripEvent(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, eventType, now, source == "User" ? currentUser.UserId : null,
            source, metadata is null ? null : JsonSerializer.Serialize(metadata), now));
    }

    private TripStop[] CreateStops(Guid tripId, IReadOnlyList<RouteStopRequest> stops) =>
        stops.Select(stop => new TripStop(
            Guid.NewGuid(), currentUser.CompanyId, tripId, stop.Sequence,
            Enum.Parse<TripStopType>(stop.Type, true), stop.Name, stop.Address,
            stop.Latitude, stop.Longitude, stop.PlannedArrivalAt,
            stop.PlannedServiceDurationMinutes, clock.UtcNow)).ToArray();

    private static bool RouteInputsChanged(Trip trip, IReadOnlyList<RouteStopRequest> stops)
    {
        if (trip.RoutePlan is null) return true;
        return !Enum.TryParse<RouteProfile>(trip.RoutePlan.RouteProfile, out var profile)
            || RoutePlanningService.Fingerprint(stops, profile)
                != trip.RoutePlan.StopsFingerprint;
    }

    private static AssignmentResourceOptionResponse TruckOption(
        Truck truck, bool tripCanAssign, ResourceReservation? reservation)
    {
        var reason = !tripCanAssign ? "TRIP_NOT_READY_FOR_ASSIGNMENT"
            : !truck.IsActive ? "RESOURCE_INACTIVE"
            : reservation is not null ? "TRUCK_ALREADY_ASSIGNED"
            : truck.Status == TruckStatus.Maintenance ? "TRUCK_MAINTENANCE"
            : truck.Status == TruckStatus.OutOfService ? "TRUCK_OUT_OF_SERVICE"
            : truck.Status == TruckStatus.OnTrip ? "TRUCK_ALREADY_ASSIGNED"
            : "AVAILABLE";
        return new(truck.Id, truck.PlateNumber, truck.Status.ToString(),
            reason == "AVAILABLE", reason, reservation?.TripId,
            reservation?.TripNumber);
    }

    private static AssignmentResourceOptionResponse DriverOption(
        Driver driver, bool tripCanAssign, ResourceReservation? reservation)
    {
        var reason = !tripCanAssign ? "TRIP_NOT_READY_FOR_ASSIGNMENT"
            : !driver.IsActive ? "RESOURCE_INACTIVE"
            : reservation is not null ? "DRIVER_ALREADY_ASSIGNED"
            : driver.Status == DriverStatus.OnTrip ? "DRIVER_ON_TRIP"
            : driver.Status != DriverStatus.Available ? "DRIVER_NOT_AVAILABLE"
            : "AVAILABLE";
        return new(driver.Id, driver.FullName, driver.Status.ToString(),
            reason == "AVAILABLE", reason, reservation?.TripId,
            reservation?.TripNumber);
    }

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

    private static string[] AllowedActions(Trip trip)
    {
        var actions = trip.Status switch
        {
            TripStatus.Draft => new List<string> { "edit", "delete", "cancel" },
            TripStatus.Assigned => ["reassign", "unassign", "preview-repositioning", "dispatch-to-pickup", "cancel"],
            TripStatus.EnRouteToPickup => ["arrive-pickup", "cancel"],
            TripStatus.AtPickup => ["start", "cancel"],
            TripStatus.Started => ["mark-in-transit", "cancel"],
            TripStatus.InTransit => ["deliver", "cancel"],
            TripStatus.Delivered => ["complete"],
            TripStatus.Completed or TripStatus.Cancelled when !trip.IsArchived => ["archive"],
            TripStatus.Completed or TripStatus.Cancelled when trip.IsArchived => ["unarchive"],
            _ => []
        };
        if (trip.Status == TripStatus.Draft && Readiness(trip).CanAssign)
            actions.Insert(2, "assign");
        actions.Add("duplicate");
        return actions.ToArray();
    }
}
