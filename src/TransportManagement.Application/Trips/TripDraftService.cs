using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Common;
using TransportManagement.Application.Routing;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Trips;

public sealed class TripDraftService(
    ITripStore tripStore,
    ITrackingStore trackingStore,
    ICurrentUser currentUser,
    IClock clock,
    TripEntityResolver resolver,
    TripEventWriter events)
{
    public async Task<TripResponse> CreateAsync(TripRequest request, CancellationToken cancellationToken)
    {
        await resolver.ActiveClientAsync(request.ClientId, cancellationToken);
        var now = clock.UtcNow;
        var number = await tripStore.AllocateTripNumberAsync(
            currentUser.CompanyId, now.UtcDateTime.Year, cancellationToken);
        var trip = new Trip(Guid.NewGuid(), currentUser.CompanyId, number,
            request.ClientId, request.CargoDescription, request.PlannedStartAt,
            request.Price, request.Notes, now);
        if (request.Stops is { Count: > 0 })
            trip.ReplaceStops(CreateStops(trip.Id, request.Stops), trip.Version, now);
        tripStore.AddTrip(trip);
        events.Append(trip, "TripCreated", new { trip.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> UpdateAsync(
        Guid id, TripRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        await resolver.ActiveClientAsync(request.ClientId, cancellationToken);
        var changed = trip.UpdateDraft(request.ClientId, request.CargoDescription,
            request.PlannedStartAt, request.Price, request.Notes,
            request.ExpectedVersion ?? trip.Version, clock.UtcNow);
        if (!changed) return TripResponseMapper.Map(trip);
        events.Append(trip, "DraftUpdated");
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task<TripResponse> UpdateStopsAsync(
        Guid id, UpdateTripStopsRequest request, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        var stops = CreateStops(trip.Id, request.Stops);
        var replacesStopEntities = trip.Stops.Count != stops.Length
            || !trip.Stops.OrderBy(x => x.Sequence).Select(x => (x.Sequence, x.Type))
                .SequenceEqual(stops.OrderBy(x => x.Sequence).Select(x => (x.Sequence, x.Type)));
        var invalidateRoute = RouteInputsChanged(trip, request.Stops);
        var previousRouteId = trip.RoutePlan?.Id;
        var replacement = trip.ReplaceStops(stops, request.ExpectedVersion, clock.UtcNow, invalidateRoute);
        if (!replacement.StopsChanged) return TripResponseMapper.Map(trip);
        if (replacesStopEntities) tripStore.AddTripStops(stops);
        events.Append(trip, "StopsUpdated");
        if (replacement.RouteInvalidated)
            events.Append(trip, "RouteInvalidated", new { previousRouteId });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(trip);
    }

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var trip = await resolver.TripAsync(id, cancellationToken);
        if (trip.Status != TripStatus.Draft || trip.RepositioningPlans.Count != 0
            || trip.ActualStartAt.HasValue || trip.ArrivedPickupAt.HasValue
            || await trackingStore.HasTripHistoryAsync(id, cancellationToken))
            throw new ConflictException("Only a never-executed Draft may be permanently deleted.", "TRIP_DELETE_NOT_ALLOWED");
        tripStore.RemoveTrip(trip);
        await tripStore.SaveChangesAsync(cancellationToken);
    }

    public async Task<TripResponse> DuplicateAsync(Guid id, CancellationToken cancellationToken)
    {
        var source = await resolver.TripAsync(id, cancellationToken);
        await resolver.ActiveClientAsync(source.ClientId, cancellationToken);
        var now = clock.UtcNow;
        var number = await tripStore.AllocateTripNumberAsync(
            currentUser.CompanyId, now.UtcDateTime.Year, cancellationToken);
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
        tripStore.AddTrip(copy);
        events.Append(copy, "TripCreated", new
            { duplicatedFromTripId = source.Id, source.TripNumber });
        await tripStore.SaveChangesAsync(cancellationToken);
        return TripResponseMapper.Map(copy);
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
            || RoutePlanningService.Fingerprint(stops, profile) != trip.RoutePlan.StopsFingerprint;
    }
}
