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
    IClock clock, TrackingPolicy trackingPolicy)
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
                null, null, null, null, null, []);

        var driverProjection = new DriverWorkspaceDriver(driver.Id, driver.FullName);
        var trip = await identities.GetCurrentTripAsync(driver.Id, cancellationToken);
        if (trip is null)
            return new("NO_ACTIVE_TRIP", driverProjection, null, null, null, "NoTrip",
                null, null, null, null, null, []);

        var mappedTrip = TripResponseMapper.Map(trip);
        if (trip.TruckId is null)
            return new("TRIP_ASSIGNED_NO_TELEMETRY", driverProjection, mappedTrip,
                null, null, "NoTelemetry", mappedTrip.RoutePlan,
                mappedTrip.RepositioningPlan, NextStop(mappedTrip), null, null,
                mappedTrip.AllowedActions);

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
                mappedTrip.AllowedActions);

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
            mappedTrip.AllowedActions);
    }

    public async Task<TripResponse> ConfirmLoadedAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmLoadedAsync(trip.Id, "User", null, cancellationToken);
    }

    public async Task<TripResponse> ConfirmDeliveryAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        return await lifecycle.ConfirmDeliveryAsync(trip.Id, "User", null, cancellationToken);
    }

    public async Task<TruckPhotoContent> TruckPhotoAsync(CancellationToken cancellationToken)
    {
        var trip = await RequiredTripAsync(cancellationToken);
        if (trip.TruckId is null)
            throw new NotFoundException("The current trip has no assigned truck.", "TRUCK_NOT_FOUND");
        return await photos.ReadAsync(trip.TruckId.Value, true, cancellationToken);
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

    private static (decimal? Remaining, DateTimeOffset? Eta) Progress(Trip trip,
        decimal latitude, decimal longitude, decimal speed, DateTimeOffset now)
    {
        string? geometry;
        decimal distance;
        if (trip.Status == TripStatus.EnRouteToPickup)
        {
            var approach = trip.RepositioningPlans.OrderByDescending(x => x.CreatedAt).FirstOrDefault();
            geometry = approach?.Geometry;
            distance = approach?.DistanceMeters ?? 0;
        }
        else
        {
            geometry = trip.RoutePlan?.Geometry;
            distance = trip.RoutePlan?.DistanceMeters ?? 0;
        }
        if (geometry is null || distance <= 0) return (null, null);
        var route = RouteGeometry.FromGeoJson(geometry);
        var projection = RouteGeometry.Project(route, new(latitude, longitude));
        var remaining = Math.Max(0, distance - projection.DistanceAlongRouteMeters);
        var eta = speed > 0.5m
            ? now.AddSeconds((double)(remaining / (speed * 1000 / 3600)))
            : (DateTimeOffset?)null;
        return (decimal.Round(remaining, 1), eta);
    }
}
