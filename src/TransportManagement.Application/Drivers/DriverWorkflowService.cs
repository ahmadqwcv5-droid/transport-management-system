using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Tracking;
using TransportManagement.Application.Trips;
using TransportManagement.Application.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Drivers;

public sealed class DriverWorkflowService(IDriverIdentityStore identities,
    ICurrentUser currentUser, TripLifecycleService lifecycle,
    IFleetStore fleet, ITrackingStore tracking, TruckPhotoService photos,
    IClock clock, TrackingPolicy trackingPolicy, DispatchPolicy dispatchPolicy,
    DriverDepartureService departure)
{
    public async Task<DriverMyTripResponse> MyTripAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken);
        return new(driver.Id, driver.FullName,
            trip is null ? null : TripResponseMapper.Map(trip));
    }

    public async Task<DriverWorkspaceResponse> WorkspaceAsync(CancellationToken cancellationToken)
    {
        var driver = await identities.GetDriverByUserAsync(currentUser.UserId, cancellationToken);
        if (driver is null)
            return new("ACCOUNT_NOT_LINKED", null, null, null, null, "Unavailable",
                null, null, null, null, null, [], []);

        var driverProjection = new DriverWorkspaceDriver(driver.Id, driver.FullName);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken);
        if (trip is null)
        {
            var session = await identities.GetActiveSessionAsync(driver.Id, cancellationToken);
            if (session is null)
                return new("NO_ACTIVE_TRIP", driverProjection, null, null, null, "NoTrip",
                    null, null, null, null, null, [], []);
            var lastTrip = await identities.GetTripAsync(session.LastTripId, cancellationToken);
            var sessionTruck = await fleet.GetTruckAsync(session.TruckId, cancellationToken);
            var sessionPhoto = await photos.MetadataAsync(session.TruckId, cancellationToken);
            var sessionPosition = await tracking.LatestPositionAsync(session.TruckId, cancellationToken);
            var mapped = lastTrip is null ? null : TripResponseMapper.Map(lastTrip);
            return new("POST_TRIP_VEHICLE", driverProjection, mapped,
                sessionTruck is null ? null : new(sessionTruck.Id, sessionTruck.PlateNumber,
                    sessionTruck.FleetCode, sessionPhoto?.Version, sessionPhoto is null ? null
                        : $"/api/driver/my-trip/truck-photo/thumbnail?v={sessionPhoto.Version}"),
                sessionPosition is null ? null : new(sessionPosition.Latitude, sessionPosition.Longitude,
                    sessionPosition.Speed, sessionPosition.Heading, sessionPosition.RecordedAt, sessionPosition.IsOnline),
                sessionPosition is null ? "NoTelemetry" : "Current", mapped?.RoutePlan,
                mapped?.RepositioningPlan, null, 0, null, ["end-vehicle-session"],
                [new("END_VEHICLE_SESSION", true, true, null, true)],
                new(session.Id, session.TruckId, session.LastTripId, session.StartedAt));
        }

        var mappedTrip = TripResponseMapper.Map(trip);
        if (trip.TruckId is null)
            return new("TRIP_ASSIGNED_NO_TELEMETRY", driverProjection, mappedTrip,
                null, null, "NoTelemetry", mappedTrip.RoutePlan,
                mappedTrip.RepositioningPlan, NextStop(mappedTrip), null, null,
                DriverActions(trip.Status), Readiness(trip, null));

        var truck = await fleet.GetTruckAsync(trip.TruckId.Value, cancellationToken);
        var photo = await photos.MetadataAsync(trip.TruckId.Value, cancellationToken);
        var truckProjection = truck is null ? null : new DriverWorkspaceTruck(
            truck.Id, truck.PlateNumber, truck.FleetCode, photo?.Version,
            photo is null ? null : $"/api/driver/my-trip/truck-photo/thumbnail?v={photo.Version}");
        var position = await tracking.LatestPositionAsync(trip.TruckId.Value, cancellationToken);
        if (position is null)
            return new("TRIP_ASSIGNED_NO_TELEMETRY", driverProjection, mappedTrip,
                truckProjection, null, "NoTelemetry", mappedTrip.RoutePlan,
                mappedTrip.RepositioningPlan, NextStop(mappedTrip), null, null,
                DriverActions(trip.Status), Readiness(trip, null));

        var age = clock.UtcNow - position.RecordedAt;
        var state = !position.IsOnline ? "TRUCK_OFFLINE"
            : age > trackingPolicy.OfflineThreshold ? "TRUCK_POSITION_STALE"
            : "ACTIVE_TRIP_READY";
        var trackingState = state switch
        {
            "TRUCK_OFFLINE" => "Offline",
            "TRUCK_POSITION_STALE" => "Stale",
            _ => "Current"
        };
        var positionProjection = new DriverWorkspacePosition(position.Latitude,
            position.Longitude, position.Speed, position.Heading, position.RecordedAt,
            position.IsOnline);
        var (remaining, eta) = Progress(trip, position.Latitude, position.Longitude,
            position.Speed, clock.UtcNow);
        return new(state, driverProjection, mappedTrip, truckProjection,
            positionProjection, trackingState, mappedTrip.RoutePlan,
            mappedTrip.RepositioningPlan, NextStop(mappedTrip), remaining, eta,
            DriverActions(trip.Status), Readiness(trip, position));
    }

    public async Task<TripResponse> ConfirmLoadedAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmLoadedAsync(trip.Id, "User", null, cancellationToken);
    }

    public async Task<TripResponse> DepartToPickupAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken)
            ?? throw new NotFoundException("No current trip is assigned to this driver.",
                "DRIVER_TRIP_NOT_FOUND");
        return await departure.PrepareAndDepartToPickupAsync(
            driver.Id, trip.Id, cancellationToken);
    }

    public async Task EndVehicleSessionAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        if (await identities.GetCurrentTripAsync(driver.Id, cancellationToken) is not null)
            throw new ConflictException("Complete the active trip before ending the vehicle session.",
                "ACTIVE_TRIP_EXISTS");
        var session = await identities.GetActiveSessionAsync(driver.Id, cancellationToken)
            ?? throw new NotFoundException("No active vehicle session was found.", "VEHICLE_SESSION_NOT_FOUND");
        session.End("DriverEnded", clock.UtcNow);
        await identities.SaveChangesAsync(cancellationToken);
    }

    public async Task<TripResponse> ConfirmDeliveryAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmDeliveryAsync(trip.Id, "User", null, cancellationToken);
    }

    public async Task<TruckPhotoContent> TruckPhotoAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken);
        var truckId = trip?.TruckId ?? (await identities.GetActiveSessionAsync(
            driver.Id, cancellationToken))?.TruckId;
        if (truckId is null)
            throw new NotFoundException("The driver has no associated truck.", "TRUCK_NOT_FOUND");
        return await photos.ReadAsync(truckId.Value, true, cancellationToken);
    }

    private async Task<Domain.Fleet.Driver> RequiredDriverAsync(CancellationToken cancellationToken) =>
        await identities.GetDriverByUserAsync(currentUser.UserId, cancellationToken)
        ?? throw new NotFoundException("The signed-in user is not linked to a driver.",
            "DRIVER_LINK_REQUIRED");

    private async Task<Trip> RequiredTripAsync(CancellationToken cancellationToken)
    {
        var driver = await RequiredDriverAsync(cancellationToken);
        return await identities.GetCurrentTripAsync(driver.Id, cancellationToken)
            ?? throw new NotFoundException("No current trip is assigned to this driver.",
                "DRIVER_TRIP_NOT_FOUND");
    }

    private static TripStopResponse? NextStop(TripResponse trip) => trip.Stops
        .OrderBy(x => x.Sequence)
        .FirstOrDefault(x => trip.Status is TripStatus.Assigned or TripStatus.EnRouteToPickup
            or TripStatus.AtPickup ? x.Type == TripStopType.Pickup : x.Type == TripStopType.Delivery);

    private static string[] DriverActions(TripStatus status) => status switch
    {
        TripStatus.Assigned => ["depart-to-pickup"],
        TripStatus.AtPickup => ["confirm-loaded-and-depart"],
        TripStatus.AtDelivery => ["confirm-delivery"],
        _ => []
    };

    private DriverActionReadinessResponse[] Readiness(
        Trip trip, Domain.Tracking.TruckPosition? position)
    {
        if (trip.Status == TripStatus.Assigned)
        {
            var pickup = trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault();
            var reason = trip.TruckId is null || position is null
                ? "TRUCK_POSITION_REQUIRED"
                : !position.IsOnline ? "TRUCK_OFFLINE"
                : clock.UtcNow - position.RecordedAt > dispatchPolicy.MaximumPositionAge
                    ? "TRUCK_POSITION_STALE"
                    : pickup?.Latitude is null || pickup.Longitude is null
                        ? "PICKUP_COORDINATES_REQUIRED" : null;
            return [new("DEPART_TO_PICKUP", true, reason is null, reason, true)];
        }
        return trip.Status switch
        {
            TripStatus.AtPickup =>
                [new("CONFIRM_LOADED_AND_DEPART", true, true, null, true)],
            TripStatus.AtDelivery =>
                [new("CONFIRM_DELIVERY", true, true, null, true)],
            _ => []
        };
    }

    private static (decimal? Remaining, DateTimeOffset? Eta) Progress(Trip trip,
        decimal latitude, decimal longitude, decimal speed, DateTimeOffset now)
    {
        string? geometry;
        decimal distance;
        int estimatedDurationSeconds;
        if (trip.Status == TripStatus.EnRouteToPickup)
        {
            var approach = trip.RepositioningPlans.OrderByDescending(x => x.CreatedAt).FirstOrDefault();
            geometry = approach?.Geometry;
            distance = approach?.DistanceMeters ?? 0;
            estimatedDurationSeconds = approach?.EstimatedDurationSeconds ?? 0;
        }
        else
        {
            geometry = trip.RoutePlan?.Geometry;
            distance = trip.RoutePlan?.DistanceMeters ?? 0;
            estimatedDurationSeconds = trip.RoutePlan?.EstimatedDurationSeconds ?? 0;
        }
        if (geometry is null || distance <= 0) return (null, null);
        var route = RouteGeometry.FromGeoJson(geometry);
        var projection = RouteGeometry.Project(route, new(latitude, longitude));
        var remaining = Math.Max(0, distance - projection.DistanceAlongRouteMeters);
        DateTimeOffset? eta = speed > 0.5m
            ? now.AddSeconds((double)(remaining / (speed * 1000 / 3600)))
            : estimatedDurationSeconds > 0
                ? now.AddSeconds((double)(remaining / distance * estimatedDurationSeconds)) : null;
        return (decimal.Round(remaining, 1), eta);
    }
}
