using System.Text.Json;
using TransportManagement.Application.Abstractions;
using TransportManagement.Application.Routing;
using TransportManagement.Application.Trips;
using TransportManagement.Domain.Tracking;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Tracking;

public sealed record GeofencePolicy(decimal ArrivalRadiusMeters, decimal ExitRadiusMeters,
    int MinimumSamples, TimeSpan MinimumDwell, TimeSpan MaximumSampleAge);

public sealed class GeofenceEvaluationService(
    ITripStore trips, IGeofenceStore observations, INotificationStore notifications,
    ICurrentUser currentUser, IClock clock, GeofencePolicy policy,
    TripEventWriter events, ResourceEventWriter resourceEvents)
{
    public async Task<bool> EvaluateAsync(TruckPosition position,
        CancellationToken cancellationToken)
    {
        if (!position.IsOnline || position.TripId is not Guid tripId
            || position.RecordedAt > clock.UtcNow.AddSeconds(5)
            || clock.UtcNow - position.RecordedAt > policy.MaximumSampleAge)
            return false;
        var trip = await trips.GetTripAsync(tripId, cancellationToken);
        if (trip is null || trip.TruckId != position.TruckId) return false;
        var stage = trip.Status switch
        {
            TripStatus.EnRouteToPickup when position.MovementPhase == MovementPhase.Repositioning
                => GeofenceStage.Pickup,
            TripStatus.InTransit when position.MovementPhase == MovementPhase.Cargo
                => GeofenceStage.Delivery,
            _ => (GeofenceStage?)null
        };
        if (stage is null) return false;
        var stop = stage == GeofenceStage.Pickup
            ? trip.Stops.OrderBy(x => x.Sequence).FirstOrDefault()
            : trip.Stops.OrderBy(x => x.Sequence).LastOrDefault();
        if (stop?.Latitude is not decimal latitude || stop.Longitude is not decimal longitude)
            return false;
        var routeIdentity = stage == GeofenceStage.Pickup
            ? trip.CurrentRepositioningPlan?.Id.ToString("N") ?? $"direct-{trip.Version}"
            : trip.RoutePlan?.Id.ToString("N") ?? "missing-route";
        var observation = await observations.GetAsync(trip.Id, stage.Value,
            routeIdentity, cancellationToken);
        if (observation is null)
        {
            observation = new(Guid.NewGuid(), currentUser.CompanyId, trip.Id,
                stage.Value, routeIdentity, clock.UtcNow);
            observations.Add(observation);
        }
        var distance = RouteGeometry.DistanceMeters([
            new(position.Latitude, position.Longitude), new(latitude, longitude)]);
        var qualified = observation.Observe(distance, position.RecordedAt,
            policy.ArrivalRadiusMeters, policy.ExitRadiusMeters, policy.MinimumSamples,
            policy.MinimumDwell, clock.UtcNow);
        if (!qualified)
        {
            await notifications.SaveChangesAsync(cancellationToken);
            return false;
        }

        var type = stage == GeofenceStage.Pickup
            ? "TruckArrivedAtPickup" : "TruckArrivedAtDelivery";
        if (stage == GeofenceStage.Pickup) trip.MarkAtPickup(position.RecordedAt);
        else trip.MarkAtDelivery(position.RecordedAt);
        events.Append(trip, stage == GeofenceStage.Pickup
            ? "ArrivedAtPickup" : "ArrivedAtDelivery", new
            { positionId = position.Id, distanceMeters = distance }, "System");
        resourceEvents.Truck(position.TruckId, type,
            new { tripId = trip.Id, trip.TripNumber, positionId = position.Id }, "System");
        var eventKey = $"{type}:{trip.Id:N}:{routeIdentity}";
        if (!await notifications.EventExistsAsync(eventKey, cancellationToken))
            notifications.Add(new OperationNotification(Guid.NewGuid(), currentUser.CompanyId,
                type, "Info", trip.Id, trip.TruckId, trip.DriverId, eventKey,
                JsonSerializer.Serialize(new { trip.TripNumber, distanceMeters = distance }),
                clock.UtcNow));
        await notifications.SaveChangesAsync(cancellationToken);
        return true;
    }
}
