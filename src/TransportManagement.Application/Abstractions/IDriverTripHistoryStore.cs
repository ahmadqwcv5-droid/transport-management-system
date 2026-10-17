using TransportManagement.Application.Drivers;
using TransportManagement.Domain.Tracking;

namespace TransportManagement.Application.Abstractions;

public interface IDriverTripHistoryStore
{
    Task<(IReadOnlyList<DriverTripHistoryListRecord> Items, int TotalCount)> QueryAsync(
        Guid driverId, DriverTripHistoryQuery query,
        CancellationToken cancellationToken);

    Task<DriverTripHistoryDetailRecord?> DetailAsync(
        Guid driverId, Guid tripId, CancellationToken cancellationToken);

    Task<IReadOnlyList<TruckPosition>> TrailCandidatesAsync(
        Guid tripId, Guid truckId, int limit,
        CancellationToken cancellationToken);
}
