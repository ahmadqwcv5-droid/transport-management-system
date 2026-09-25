using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Clients;
using TransportManagement.Domain.Common;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;
using System.Text.Json;

namespace TransportManagement.Application.Trips;

internal static class TripResponseMapper
{
    public static TripResponse Map(Trip trip) => new(
        trip.Id, trip.TripNumber, trip.ClientId, trip.TruckId, trip.DriverId, trip.Origin, trip.Destination,
        trip.CargoDescription, trip.PlannedStartAt, trip.ActualStartAt, trip.ArrivedPickupAt,
        trip.ArrivedDeliveryAt, trip.DeliveredAt,
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
        trip.RepositioningPlans.OrderByDescending(x => x.CalculatedAt)
            .Select(Map).FirstOrDefault(),
        trip.RoutePlan is null || trip.Stops.Any(x => !x.HasCoordinates),
        trip.CreatedAt, trip.UpdatedAt);

    public static TripReadinessResponse Readiness(Trip trip)
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

    public static TripRepositioningPlanResponse Map(TripRepositioningPlan plan) => new(
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
            TripStatus.Assigned => ["reassign", "unassign", "preview-repositioning", "override-dispatch-to-pickup", "cancel"],
            TripStatus.EnRouteToPickup => ["arrive-pickup", "cancel"],
            TripStatus.AtPickup => ["confirm-loaded", "start", "cancel"],
            TripStatus.Started => ["mark-in-transit", "cancel"],
            TripStatus.InTransit => ["deliver", "cancel"],
            TripStatus.AtDelivery => ["confirm-delivery"],
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

public sealed class TripEntityResolver(
    ITripStore tripStore,
    IClientStore clientStore,
    IFleetStore fleetStore)
{
    public async Task<Trip> TripAsync(Guid id, CancellationToken cancellationToken) =>
        await tripStore.GetTripAsync(id, cancellationToken)
        ?? throw new NotFoundException("Trip was not found.", "TRIP_NOT_FOUND");

    public async Task<Client> ActiveClientAsync(Guid id, CancellationToken cancellationToken)
    {
        var client = await clientStore.GetClientAsync(id, cancellationToken)
            ?? throw new NotFoundException("Client was not found in the current company.", "CLIENT_NOT_FOUND");
        if (!client.IsActive)
            throw new ConflictException("The selected client is inactive.", "CLIENT_INACTIVE");
        return client;
    }

    public async Task<Truck> TruckAsync(Guid id, CancellationToken cancellationToken) =>
        await fleetStore.GetTruckAsync(id, cancellationToken)
        ?? throw new NotFoundException("Truck was not found in the current company.", "TRUCK_NOT_FOUND");

    public async Task<Driver> DriverAsync(Guid id, CancellationToken cancellationToken) =>
        await fleetStore.GetDriverAsync(id, cancellationToken)
        ?? throw new NotFoundException("Driver was not found in the current company.", "DRIVER_NOT_FOUND");

    public async Task<(Trip Trip, Truck Truck, Driver Driver)> AssignedResourcesAsync(
        Guid id, CancellationToken cancellationToken)
    {
        var trip = await TripAsync(id, cancellationToken);
        if (trip.TruckId is null || trip.DriverId is null)
            throw new DomainRuleException("The trip has no assigned truck and driver.");
        return (trip, await TruckAsync(trip.TruckId.Value, cancellationToken),
            await DriverAsync(trip.DriverId.Value, cancellationToken));
    }
}

public sealed class TripEventWriter(
    ITripStore tripStore, ICurrentUser currentUser, IClock clock)
{
    public void Append(Trip trip, string eventType, object? metadata = null,
        string source = "User")
    {
        var now = clock.UtcNow;
        tripStore.AddTripEvent(new TripEvent(Guid.NewGuid(), currentUser.CompanyId,
            trip.Id, eventType, now,
            source is "User" or "ManagerOverride" ? currentUser.UserId : null,
            source, metadata is null ? null : JsonSerializer.Serialize(metadata), now));
    }
}
