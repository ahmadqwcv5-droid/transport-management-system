using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface IGeofenceStore
{
    Task<TripGeofenceObservation?> GetAsync(Guid tripId, GeofenceStage stage,
        string routeIdentity, CancellationToken cancellationToken);
    void Add(TripGeofenceObservation observation);
}
