using TransportManagement.Application.Trips;
using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface ITripQueryStore
{
    Task<Trip?> GetTripAsync(Guid id, CancellationToken cancellationToken);
    Task<(IReadOnlyList<Trip> Items, int TotalCount)> QueryTripsAsync(
        TripListQuery query, CancellationToken cancellationToken);
    Task<IReadOnlyList<Trip>> ListTripsAsync(
        TripStatus? status, Guid? clientId, Guid? truckId, Guid? driverId,
        DateTimeOffset? plannedFrom, DateTimeOffset? plannedTo,
        CancellationToken cancellationToken);
    Task<(IReadOnlyList<TripEvent> Items, int TotalCount)> ListTripEventsAsync(
        Guid tripId, int page, int pageSize, CancellationToken cancellationToken);
    Task<string?> UserDisplayNameAsync(Guid userId, CancellationToken cancellationToken);
}
