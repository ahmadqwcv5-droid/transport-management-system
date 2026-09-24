using TransportManagement.Application.Abstractions;
using TransportManagement.Domain.Fleet;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed class TripLifecycleService(
    ITripStore tripStore,
    ICurrentUser currentUser,
    IClock clock,
    TripEntityResolver resolver,
    TripEventWriter events,
    ResourceEventWriter resourceEvents)
{
    public Task<TripResponse> MarkInTransitAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.MarkInTransit(now),
            "MarkedInTransit", cancellationToken);

    public Task<TripResponse> DeliverAsync(Guid id, CancellationToken cancellationToken) =>
        TransitionAsync(id, (trip, now) => trip.Deliver(now), "Delivered", cancellationToken);

    public async Task<TripResponse> CompleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var (trip, truck, driver) = await resolver.AssignedResourcesAsync(id, cancellationToken);
        var now = clock.UtcNow;
        trip.Complete(now);
        driver.ChangeStatus(DriverStatus.Available, now);
        events.Append(trip, "Completed");
        resourceEvents.Truck(truck.Id, "TruckTripCompleted",
            new { tripId = trip.Id, trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> CancelAsync(
        Guid id, CancelTripRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        var release = trip.Status is TripStatus.EnRouteToPickup or TripStatus.AtPickup
            or TripStatus.Started or TripStatus.InTransit;
        Truck? truck = null;
        Driver? driver = null;
        if (release) (_, truck, driver) = await resolver.AssignedResourcesAsync(id, cancellationToken);
        var now = clock.UtcNow;
        var previousStatus = trip.Status;
        trip.Cancel(request.Reason, currentUser.UserId, now);
        driver?.ChangeStatus(DriverStatus.Available, now);
        events.Append(trip, "Cancelled", new
            { previousStatus, reason = trip.CancellationReason });
        if (trip.TruckId is Guid truckId)
            resourceEvents.Truck(truckId, "TruckTripCancelled",
                new { tripId = trip.Id, trip.TripNumber, previousStatus });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> ArchiveAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        trip.Archive(currentUser.UserId, clock.UtcNow);
        events.Append(trip, "Archived");
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> UnarchiveAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        trip.Unarchive(clock.UtcNow);
        events.Append(trip, "Unarchived");
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    private async Task<TripResponse> TransitionAsync(Guid id,
        Action<Trip, DateTimeOffset> transition, string eventType,
        CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        transition(trip, clock.UtcNow);
        events.Append(trip, eventType);
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }
}
