using TransportManagement.Domain.Trips;

namespace TransportManagement.Application.Abstractions;

public interface ITripStore
{
    Task<Trip?> GetTripAsync(Guid id, CancellationToken cancellationToken);
    Task<Trip?> ReloadTripAsync(Guid id, CancellationToken cancellationToken);
    Task<string> AllocateTripNumberAsync(Guid companyId, int year, CancellationToken cancellationToken);
    void AddTrip(Trip trip);
    void AddTripStops(IReadOnlyCollection<TripStop> stops);
    void RemoveTrip(Trip trip);
    void AddTripEvent(TripEvent tripEvent);
    void AddRepositioningPlan(TripRepositioningPlan plan);
    void AddTripRoutePlan(TripRoutePlan plan);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
